import fs from "node:fs/promises";
import { constants as fsConstants } from "node:fs";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { processIsAlive, readLockOwner } from "./shared.mjs";

export async function resolveRealDirectory(directory, label) {
  const original = await fs.lstat(directory);
  if (!original.isDirectory() || original.isSymbolicLink()) throw new Error(`${label} must be a real directory`);
  const resolved = await fs.realpath(directory);
  const resolvedStat = await fs.lstat(resolved);
  if (!resolvedStat.isDirectory() || resolvedStat.isSymbolicLink()) throw new Error(`${label} must be a real directory`);
  return resolved;
}

export async function syncDirectory(directory) {
  const handle = await fs.open(directory, fsConstants.O_RDONLY);
  try { await handle.sync(); }
  finally { await handle.close(); }
}

export async function writeDurableExclusive(filePath, bytes) {
  const handle = await fs.open(filePath, "wx", 0o600);
  try {
    await handle.writeFile(bytes);
    await handle.sync();
  } finally {
    await handle.close();
  }
  await syncDirectory(path.dirname(filePath));
}

export async function acquireLock(root) {
  const lock = path.join(root, ".theme-import.lock");
  const token = randomUUID();
  while (true) {
    try {
      await fs.mkdir(lock, { mode: 0o700 });
      break;
    } catch (error) {
      if (error.code !== "EEXIST") throw error;
      const stat = await fs.lstat(lock).catch(() => null);
      if (!stat?.isDirectory() || stat.isSymbolicLink()) throw new Error("Theme import lock is not a trusted directory");
      const owner = await readLockOwner(lock);
      if (owner && processIsAlive(owner.pid)) throw new Error("Another theme import is still running; try again shortly");
      if (!owner && Date.now() - stat.mtimeMs < 5 * 60 * 1000) {
        throw new Error("Another theme import is still starting; try again shortly");
      }
      const abandoned = path.join(root, `.theme-import-lock-stale-${randomUUID()}`);
      try { await fs.rename(lock, abandoned); }
      catch (renameError) {
        if (renameError.code === "ENOENT") continue;
        throw renameError;
      }
      await fs.rm(abandoned, { recursive: true, force: true });
    }
  }

  const owner = { pid: process.pid, token, createdAt: new Date().toISOString() };
  try {
    await writeDurableExclusive(
      path.join(lock, "owner.json"),
      Buffer.from(`${JSON.stringify(owner)}\n`, "utf8"),
    );
    await syncDirectory(root);
  } catch (error) {
    await fs.rm(lock, { recursive: true, force: true }).catch(() => {});
    throw error;
  }

  return async () => {
    const current = await readLockOwner(lock);
    if (!current || current.token !== token || current.pid !== process.pid) return;
    const released = path.join(root, `.theme-import-lock-release-${token}`);
    try { await fs.rename(lock, released); }
    catch (error) {
      if (error.code === "ENOENT") return;
      throw error;
    }
    await fs.rm(released, { recursive: true, force: true });
    await syncDirectory(root);
  };
}
