import test from 'node:test';
import assert from 'node:assert/strict';
import { createDiscoverySignal, enableTargetDiscovery, ensureTargetDiscovery } from '../../Resources/DreamSkinRuntime/scripts/injector/discovery-signal.mjs';
import { waitForCodexProbe, CdpSession } from '../../Resources/DreamSkinRuntime/scripts/injector/cdp-session.mjs';

function sessionMock(fail = false) {
  const handlers = new Map();
  const ws = new EventTarget();
  return { handlers, ws, on: (name, fn) => handlers.set(name, fn),
    async send(method, params, timeout) {
      assert.equal(method, 'Target.setDiscoverTargets');
      assert.deepEqual(params, { discover: true });
      assert.equal(timeout, 500);
      if (fail) throw new Error('unsupported');
    },
  };
}

test('discovery wakes immediately and retains events arriving before wait', async () => {
  const signal = createDiscoverySignal();
  const revision = signal.revision;
  const waiting = signal.wait(10000, revision);
  signal.wake();
  await waiting;
  await signal.wait(10000, revision);
  const fresh = signal.revision;
  const started = Date.now();
  await signal.wait(15, fresh);
  assert.ok(Date.now() - started >= 10, 'unchanged state must retain bounded fallback');
});

test('discovery filters non-page updates, wakes on closure, and tolerates old hosts', async () => {
  let wakes = 0;
  const session = sessionMock();
  assert.equal(await enableTargetDiscovery(session, () => wakes++), true);
  session.handlers.get('Target.targetCreated')({ targetInfo: { type: 'worker' } });
  session.handlers.get('Target.targetDestroyed')({ targetId: 'worker' });
  assert.equal(wakes, 0);
  session.handlers.get('Target.targetCreated')({ targetInfo: { type: 'page', targetId: 'gone', url: 'https://untrusted.invalid' } });
  session.handlers.get('Target.targetInfoChanged')({ targetInfo: { type: 'page', targetId: 'gone' } });
  session.handlers.get('Target.targetDestroyed')({ targetId: 'gone' });
  session.ws.dispatchEvent(new Event('close'));
  assert.equal(wakes, 4);
  assert.equal(await enableTargetDiscovery(sessionMock(true), () => {}), false);
});

test('renderer probe retries context destruction without exceeding its evaluation budget', async () => {
  let calls = 0;
  const probe = await waitForCodexProbe({ closed: false, async evaluate(_expression, timeout) {
    assert.ok(timeout > 0 && timeout <= 300);
    if (++calls === 1) throw new Error('Execution context was destroyed.');
    return { codex: true };
  } }, 300);
  assert.equal(probe.codex, true);
  assert.equal(calls, 2);
  await assert.rejects(waitForCodexProbe({ async evaluate() {
    throw new Error('permission denied');
  } }, 100), /permission denied/);
});

test('CDP domain setup is concurrent and a failed setup closes the session', async () => {
  const original = globalThis.WebSocket;
  class Socket extends EventTarget {
    constructor() { super(); queueMicrotask(() => this.dispatchEvent(new Event('open'))); }
    send(raw) {
      const command = JSON.parse(raw);
      this.commands ??= [];
      this.commands.push(command);
      if (this.commands.length === 2) {
        for (const item of this.commands) {
          const event = new Event('message');
          event.data = JSON.stringify(item.method === 'Page.enable'
            ? { id: item.id, error: { message: 'setup rejected', code: -1 } }
            : { id: item.id, result: {} });
          queueMicrotask(() => this.dispatchEvent(event));
        }
      }
    }
    close() { this.didClose = true; this.dispatchEvent(new Event('close')); }
  }
  globalThis.WebSocket = Socket;
  try {
    const session = new CdpSession({ webSocketDebuggerUrl: 'ws://127.0.0.1:9341/devtools/page/test' }, 9341);
    await assert.rejects(session.open(), /setup rejected/);
    assert.equal(session.closed, true);
    assert.equal(session.pending.size, 0);
    assert.equal(session.ws.didClose, true);
  } finally { globalThis.WebSocket = original; }
});

test('a socket closed during handshake fails promptly rather than waiting five seconds', async () => {
  const original = globalThis.WebSocket;
  class ClosedSocket extends EventTarget {
    constructor() { super(); queueMicrotask(() => this.dispatchEvent(new Event('close'))); }
    close() {}
  }
  globalThis.WebSocket = ClosedSocket;
  try {
    const session = new CdpSession({ webSocketDebuggerUrl: 'ws://127.0.0.1:9341/devtools/page/test' }, 9341);
    await assert.rejects(session.open(), /closed before opening/);
    assert.equal(session.closed, true);
  } finally { globalThis.WebSocket = original; }
});

test('repeated navigation failures terminate within the probe budget', async () => {
  let calls = 0;
  const started = Date.now();
  const result = await waitForCodexProbe({ closed: false, async evaluate() {
    calls++;
    throw new Error('Cannot find context with specified id');
  } }, 70);
  assert.equal(result, null);
  assert.ok(calls >= 1 && calls <= 3);
  assert.ok(Date.now() - started < 300);
});


test('discovery leadership moves to an existing live session after its leader closes', async () => {
  const first = { session: sessionMock() };
  const second = { session: sessionMock() };
  const records = [first, second];
  assert.equal(await ensureTargetDiscovery(records, () => {}), true);
  assert.equal(first.targetDiscovery, true);
  assert.equal(second.targetDiscoveryAttempted, undefined);
  first.session.closed = true;
  assert.equal(await ensureTargetDiscovery(records, () => {}), true);
  assert.equal(second.targetDiscovery, true);
  const unsupported = { session: sessionMock(true) };
  assert.equal(await ensureTargetDiscovery([unsupported], () => {}), false);
  unsupported.session.send = () => { throw new Error('must not repeatedly retry unsupported discovery'); };
  assert.equal(await ensureTargetDiscovery([unsupported], () => {}), false);
});
