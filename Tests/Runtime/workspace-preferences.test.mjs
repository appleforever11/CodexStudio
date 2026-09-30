import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { workspaceDefaults, normalizeWorkspacePreferences, loadWorkspacePreferences } from '../../Resources/DreamSkinRuntime/scripts/injector/workspace-preferences.mjs';

test('workspace preferences reject invalid values and preserve independent surfaces', async () => {
  assert.deepEqual(normalizeWorkspacePreferences(), workspaceDefaults);
  for (const value of [{schemaVersion: 2}, {sidebarBlur: 100}, {chatOpacity: -1}, {enabled: 'true'}, {alien: 2}, []]) {
    assert.throws(() => normalizeWorkspacePreferences(value));
  }
  assert.equal(normalizeWorkspacePreferences({chatBlur: 0}).sidebarBlur, 36);
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'workspace-pref-'));
  try {
    assert.deepEqual(await loadWorkspacePreferences(path.join(root, 'theme')), workspaceDefaults);
    await fs.writeFile(path.join(root, 'workspace-ui.json'), JSON.stringify({sidebarOpacity:.2, chatOpacity:.6}));
    const settings = await loadWorkspacePreferences(path.join(root, 'theme'));
    assert.equal(settings.sidebarOpacity, .2); assert.equal(settings.chatOpacity, .6);
    await fs.writeFile(path.join(root, 'workspace-ui.json'), 'broken');
    await assert.rejects(loadWorkspacePreferences(path.join(root, 'theme')));
  } finally { await fs.rm(root, {recursive:true,force:true}); }
});

test('Dot preferences migrate older settings and validate colors and geometry', () => {
  const older = normalizeWorkspacePreferences({chatBlur: 12});
  assert.equal(older.dotBubbleColor, '#2563EB');
  assert.equal(older.dotUserBubbleColor, '#4B5563');
  assert.equal(normalizeWorkspacePreferences({dotSpacing: 24, dotEnabled: false}).dotSpacing, 24);
  for (const value of [{dotBubbleColor: 'red'}, {dotUserBubbleColor: '#fff;display:none'}, {dotSpacing: 99}, {dotRadius: -1}, {dotBackdropDim: 1}, {dotGlassBlur: 100}]) {
    assert.throws(() => normalizeWorkspacePreferences(value));
  }
});
