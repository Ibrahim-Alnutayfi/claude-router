import { mkdir, readFile, writeFile, unlink, rename } from "node:fs/promises";
import { dirname, join } from "node:path";
import { keychainGet, keychainSet, keychainDelete } from "../../../keychain.ts";
import { codexAuthFile, legacyConfigDir } from "../../../paths.ts";

export interface StoredAuth {
  access: string;
  refresh: string;
  expires: number;
  accountId?: string;
}

function file(): string {
  return codexAuthFile();
}
function legacyFile(): string {
  return join(legacyConfigDir(), "codex", "auth.json");
}
const KEYCHAIN_SERVICE = "claude-code-proxy.codex";
const KEYCHAIN_ACCOUNT = "auth";

export async function loadAuth(): Promise<StoredAuth | undefined> {
  if (process.platform === "darwin" && !process.env.DISABLE_KEYCHAIN) {
    try {
      const raw = keychainGet(KEYCHAIN_SERVICE, KEYCHAIN_ACCOUNT);
      if (raw) return JSON.parse(raw) as StoredAuth;
      return undefined;
    } catch (err: any) {
      console.warn(`[claude-code-proxy] Keychain read failed (${err?.message || err}). Falling back to file storage.`);
    }
  }

  const primary = file();
  try {
    const raw = await readFile(primary, "utf8");
    return JSON.parse(raw) as StoredAuth;
  } catch (err: any) {
    if (err?.code !== "ENOENT") throw err;
  }
  const legacy = legacyFile();
  if (legacy === primary) return undefined;
  try {
    const raw = await readFile(legacy, "utf8");
    return JSON.parse(raw) as StoredAuth;
  } catch (err: any) {
    if (err?.code === "ENOENT") return undefined;
    throw err;
  }
}

export async function saveAuth(auth: StoredAuth): Promise<void> {
  if (process.platform === "darwin" && !process.env.DISABLE_KEYCHAIN) {
    try {
      keychainSet(KEYCHAIN_SERVICE, KEYCHAIN_ACCOUNT, JSON.stringify(auth));
      return;
    } catch (err: any) {
      console.warn(`[claude-code-proxy] Keychain write failed (${err?.message || err}). Falling back to file storage.`);
    }
  }

  const path = file();
  await mkdir(dirname(path), { recursive: true, mode: 0o700 });
  const tmp = `${path}.${process.pid}.${Date.now()}.tmp`;
  await writeFile(tmp, JSON.stringify(auth, null, 2), { encoding: "utf8", mode: 0o600 });
  await rename(tmp, path);
}

export async function clearAuth(): Promise<void> {
  if (process.platform === "darwin" && !process.env.DISABLE_KEYCHAIN) {
    try {
      keychainDelete(KEYCHAIN_SERVICE, KEYCHAIN_ACCOUNT);
    } catch (err: any) {
      console.warn(`[claude-code-proxy] Keychain delete failed (${err?.message || err}).`);
    }
  }

  for (const path of [file(), legacyFile()]) {
    try {
      await unlink(path);
    } catch (err: any) {
      if (err?.code !== "ENOENT") throw err;
    }
  }
}

export function authPath(): string {
  return (process.platform === "darwin" && !process.env.DISABLE_KEYCHAIN) ? "macOS Keychain" : file();
}
