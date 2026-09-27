import fs from 'node:fs/promises';
import path from 'node:path';

export const workspaceDefaults = Object.freeze({
  schemaVersion: 1, enabled: true,
  sidebarOpacity: 0.06, sidebarDim: 0.02, sidebarBlur: 36,
  chatOpacity: 0.14, chatDim: 0.08, chatBlur: 10,
  rowSpacing: 6, wrapTitles: true, groupResponses: true,
  preserveReading: true, showLatest: true, searchContext: true,
  readingWidth: 820, focusByDefault: false,
});
const ranges = {
  sidebarOpacity: [0, 1], sidebarDim: [0, 0.8], sidebarBlur: [0, 48],
  chatOpacity: [0, 1], chatDim: [0, 0.8], chatBlur: [0, 32],
  rowSpacing: [2, 12], readingWidth: [560, 1120],
};
export function normalizeWorkspacePreferences(value = {}) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid workspace appearance');
  const result = { ...workspaceDefaults };
  for (const [key, item] of Object.entries(value)) {
    if (!(key in workspaceDefaults)) throw new Error(`Unknown workspace preference: ${key}`);
    if (key === 'schemaVersion') {
      if (item !== 1) throw new Error('Unsupported workspace appearance version');
    } else if (ranges[key]) {
      const [min, max] = ranges[key];
      if (typeof item !== 'number' || !Number.isFinite(item) || item < min || item > max) {
        throw new Error(`Workspace preference out of range: ${key}`);
      }
    } else if (typeof item !== 'boolean') throw new Error(`Invalid workspace toggle: ${key}`);
    result[key] = item;
  }
  return result;
}
export async function loadWorkspacePreferences(themeDirectory) {
  if (!themeDirectory) return { ...workspaceDefaults };
  const file = path.join(path.dirname(themeDirectory), 'workspace-ui.json');
  try {
    const stat = await fs.lstat(file);
    if (!stat.isFile() || stat.size > 8192) throw new Error('Workspace appearance must be a small regular file');
    return normalizeWorkspacePreferences(JSON.parse(await fs.readFile(file, 'utf8')));
  } catch (error) {
    if (error.code === 'ENOENT') return { ...workspaceDefaults };
    throw error;
  }
}
