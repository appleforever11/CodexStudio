import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { watchOperationState } from "../../Resources/DreamSkinRuntime/scripts/injector/watch-sources.mjs";

test("operation watcher retries failed delivery and observes atomic replacement", async () => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "studio-operation-test-"));
  const state = path.join(directory, "operation.plist");
  const token = "123:1788654825974:456";
  let close = () => {};
  const write = async (status, updatedAt) => {
    const temporary = path.join(directory, "next.plist");
    await fs.writeFile(temporary, JSON.stringify({ operationToken: token, status, updatedAt }));
    await fs.rename(temporary, state);
  };
  try {
    await write("applying", 1);
    const received = [];
    let attempts = 0;
    close = await watchOperationState(state, async operation => {
      attempts++;
      if (attempts === 1) throw new Error("simulated unavailable renderer");
      received.push(operation.status);
    });
    const waitFor = async status => {
      const deadline = Date.now() + 5000;
      while (!received.includes(status) && Date.now() < deadline) {
        await new Promise(resolve => setTimeout(resolve, 50));
      }
      assert.ok(received.includes(status), `missing ${status}`);
    };
    await waitFor("applying");
    await write("success", 2);
    await waitFor("success");
    assert.deepEqual(received, ["applying", "success"]);
  } finally {
    close();
    await fs.rm(directory, { recursive: true, force: true });
  }
});
