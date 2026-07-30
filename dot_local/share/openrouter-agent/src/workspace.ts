import { lstatSync, realpathSync, type Stats } from 'node:fs';
import { lstat, realpath } from 'node:fs/promises';
import { homedir } from 'node:os';
import { isAbsolute, relative, resolve, sep } from 'node:path';

const SENSITIVE_SEGMENTS = new Set([
  '.hermes',
  '.ssh',
  '.gnupg',
  '.aws',
  '.azure',
  '.docker',
  '.git',
  '.jj',
  '.kube',
  '.password-store',
  '.terraform.d',
]);
const SENSITIVE_NAMES = new Set([
  '.authinfo',
  '.authinfo.gpg',
  '.envrc',
  '.git-credentials',
  '.netrc',
  '.npmrc',
  '.pgpass',
  '.pnpmrc',
  '.pypirc',
  '.vault-token',
  '.yarnrc',
  '.yarnrc.yml',
  'accesstokens.json',
  'application_default_credentials.json',
  'auth.json',
  'credentials',
  'credentials.json',
  'credentials.tfrc.json',
  'id_dsa',
  'id_ecdsa',
  'id_ed25519',
  'id_rsa',
]);
const SENSITIVE_PATH_PATTERNS = [
  ['.cache', 'huggingface'],
  ['.config', '1password'],
  ['.config', 'anthropic'],
  ['.config', 'azure'],
  ['.config', 'bitwarden'],
  ['.config', 'composer'],
  ['.config', 'configstore'],
  ['.config', 'containers'],
  ['.config', 'gcloud'],
  ['.config', 'gh'],
  ['.config', 'glab-cli'],
  ['.config', 'heroku'],
  ['.config', 'huggingface'],
  ['.config', 'openai'],
  ['.config', 'op'],
  ['.config', 'pip'],
  ['.config', 'pypoetry'],
  ['.config', 'rclone'],
  ['.config', 'sops'],
  ['.local', 'share', 'keyrings'],
] as const;

function containsPattern(parts: string[], pattern: readonly string[]): boolean {
  return parts.some((_, start) => pattern.every((part, offset) => parts[start + offset] === part));
}

function assertNotSensitive(path: string): void {
  const parts = path.split(sep).filter(Boolean).map((part) => part.toLowerCase());
  const name = parts.at(-1) ?? '';
  if (parts.some((part) => SENSITIVE_SEGMENTS.has(part))) {
    throw new Error('Local file tools refuse credential and secret directories');
  }
  if (SENSITIVE_PATH_PATTERNS.some((pattern) => containsPattern(parts, pattern))) {
    throw new Error('Local file tools refuse application credential directories');
  }
  if ((name === '.env' || name.startsWith('.env.')) && name !== '.env.example') {
    throw new Error('Local file tools refuse environment credential files');
  }
  if (SENSITIVE_NAMES.has(name)) {
    throw new Error('Local file tools refuse common credential files');
  }
  if (
    /\.(?:pem|key|p12|pfx)$/i.test(name) ||
    /(?:credential|secret).*(?:\.json|\.ya?ml|\.toml)$/i.test(name)
  ) {
    throw new Error('Local file tools refuse credential and private-key files');
  }
}

export function assertSafeWorkspaceRoot(root: string, home = homedir()): void {
  const lexicalRoot = resolve(root);
  const lexicalHome = resolve(home);
  if (lexicalRoot === lexicalHome) {
    throw new Error('Refusing to use the home directory as an agent workspace; start inside a project');
  }

  let normalizedRoot = lexicalRoot;
  try {
    const stat = lstatSync(lexicalRoot);
    if (stat.isSymbolicLink()) {
      throw new Error('Refusing to use a symlink as an agent workspace root');
    }
    normalizedRoot = realpathSync(lexicalRoot);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
  }

  let normalizedHome = lexicalHome;
  try {
    normalizedHome = realpathSync(lexicalHome);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
  }
  if (normalizedRoot === normalizedHome) {
    throw new Error('Refusing to use the home directory as an agent workspace; start inside a project');
  }
  assertNotSensitive(normalizedRoot);
}

function contained(root: string, candidate: string): boolean {
  const rel = relative(root, candidate);
  return rel === '' || (!rel.startsWith(`..${sep}`) && rel !== '..' && !isAbsolute(rel));
}

export async function resolveExistingWorkspacePath(root: string, input: string): Promise<string> {
  const rootReal = await realpath(root);
  const candidate = await realpath(resolve(rootReal, input));
  if (!contained(rootReal, candidate)) throw new Error('Path escapes the launch workspace');
  assertNotSensitive(candidate);
  return candidate;
}

export async function resolveWritableWorkspacePath(root: string, input: string): Promise<string> {
  const rootReal = await realpath(root);
  const candidate = resolve(rootReal, input);
  if (!contained(rootReal, candidate)) throw new Error('Path escapes the launch workspace');
  assertNotSensitive(candidate);

  const rel = relative(rootReal, candidate);
  const parts = rel.split(sep).slice(0, -1).filter(Boolean);
  let current = rootReal;
  for (const part of parts) {
    current = resolve(current, part);
    try {
      const stat = await lstat(current);
      if (stat.isSymbolicLink()) throw new Error('Writable path traverses a symlink');
      if (!stat.isDirectory()) throw new Error('Writable path parent is not a directory');
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') break;
      throw error;
    }
  }

  try {
    const stat = await lstat(candidate);
    if (stat.isSymbolicLink()) throw new Error('Writable path target is a symlink');
    if (!stat.isFile()) throw new Error('Writable path target is not a regular file');
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
  }
  return candidate;
}

export async function assertOpenedWorkspaceFile(
  root: string,
  candidate: string,
  openedStat: Stats,
): Promise<void> {
  if (!openedStat.isFile()) throw new Error('Opened workspace path is not a regular file');
  if (openedStat.nlink !== 1) {
    throw new Error('Writable workspace files must not have hard links');
  }

  const verifiedPath = await resolveExistingWorkspacePath(root, candidate);
  const pathStat = await lstat(verifiedPath);
  if (!pathStat.isFile()) throw new Error('Verified workspace path is not a regular file');
  if (pathStat.dev !== openedStat.dev || pathStat.ino !== openedStat.ino) {
    throw new Error('Workspace path changed while it was being opened');
  }
}
