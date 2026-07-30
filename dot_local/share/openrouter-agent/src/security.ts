import { constants } from 'node:fs';
import { lstat, open, type FileHandle } from 'node:fs/promises';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { parse } from 'dotenv';

export const DEFAULT_OPT_IN_MARKER = join(
  homedir(),
  '.config',
  'dotfiles',
  'openrouter-agent.enabled',
);
export const DEFAULT_ENV_FILE = join(homedir(), '.hermes', '.env');

function ownerUid(): number | undefined {
  return typeof process.getuid === 'function' ? process.getuid() : undefined;
}

async function privateRegularFile(
  path: string,
  options: { exactMode?: number; rejectWritableByOthers?: boolean },
): Promise<void> {
  const stat = await lstat(path);
  if (!stat.isFile() || stat.isSymbolicLink()) {
    throw new Error(`${path} must be a user-owned regular file (symlinks are rejected)`);
  }
  const uid = ownerUid();
  if (uid !== undefined && stat.uid !== uid) {
    throw new Error(`${path} must be owned by the current user`);
  }
  const mode = stat.mode & 0o777;
  if (options.exactMode !== undefined && mode !== options.exactMode) {
    throw new Error(`${path} must have mode 0600`);
  }
  if (options.rejectWritableByOthers && (mode & 0o022) !== 0) {
    throw new Error(`${path} must not be writable by group or others`);
  }
}

async function privateDirectory(path: string): Promise<void> {
  const stat = await lstat(path);
  if (!stat.isDirectory() || stat.isSymbolicLink()) {
    throw new Error(`${path} must be a user-owned directory (symlinks are rejected)`);
  }
  const uid = ownerUid();
  if (uid !== undefined && stat.uid !== uid) {
    throw new Error(`${path} must be owned by the current user`);
  }
  if (((stat.mode & 0o777) & 0o022) !== 0) {
    throw new Error(`${path} must not be writable by group or others`);
  }
}

async function readPrivateRegularFile(path: string): Promise<Buffer> {
  await privateDirectory(dirname(path));
  await privateRegularFile(path, { exactMode: 0o600 });

  let handle: FileHandle | undefined;
  try {
    handle = await open(path, constants.O_RDONLY | constants.O_NOFOLLOW);
    const stat = await handle.stat();
    const uid = ownerUid();
    if (!stat.isFile() || (uid !== undefined && stat.uid !== uid) || (stat.mode & 0o777) !== 0o600) {
      throw new Error(`${path} changed while its security properties were being checked`);
    }
    return await handle.readFile();
  } finally {
    await handle?.close();
  }
}

export async function isSecureOptInMarker(
  path = DEFAULT_OPT_IN_MARKER,
): Promise<boolean> {
  try {
    await privateDirectory(dirname(path));
    await privateRegularFile(path, { rejectWritableByOthers: true });
    return true;
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return false;
    throw error;
  }
}

export interface LoadedApiKey {
  apiKey: string;
  source: 'environment' | string;
}

export async function loadOpenRouterApiKey(options: {
  env?: NodeJS.ProcessEnv;
  envFile?: string;
} = {}): Promise<LoadedApiKey> {
  const env = options.env ?? process.env;
  const exported = env.OPENROUTER_API_KEY?.trim();
  if (exported) return { apiKey: exported, source: 'environment' };

  const envFile = options.envFile ?? DEFAULT_ENV_FILE;
  try {
    const contents = await readPrivateRegularFile(envFile);
    const parsed = parse(contents);
    const apiKey = parsed.OPENROUTER_API_KEY?.trim();
    if (!apiKey) {
      throw new Error(`${envFile} does not define a non-empty OPENROUTER_API_KEY`);
    }
    return { apiKey, source: envFile };
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
      throw new Error(
        `OPENROUTER_API_KEY is unset and the private key file does not exist: ${envFile}`,
      );
    }
    throw error;
  }
}
