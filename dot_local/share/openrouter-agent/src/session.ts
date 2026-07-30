import {
  lstat,
  mkdir,
  open,
  readFile,
  readdir,
  rename,
  rm,
} from 'node:fs/promises';
import { homedir } from 'node:os';
import { basename, join } from 'node:path';
import { randomUUID } from 'node:crypto';

export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

export interface Session {
  version: 1;
  id: string;
  createdAt: string;
  updatedAt: string;
  model: string;
  messages: ChatMessage[];
}

export function defaultSessionDir(env: NodeJS.ProcessEnv = process.env): string {
  const home = env.HOME || homedir();
  const stateHome = env.XDG_STATE_HOME || join(home, '.local', 'state');
  return join(stateHome, 'openrouter-agent', 'sessions');
}

function validSessionId(id: string): void {
  if (!/^[A-Za-z0-9._-]+$/.test(id) || id === '.' || id === '..') {
    throw new Error('Invalid session id');
  }
}

async function assertPrivate(path: string, kind: 'directory' | 'file'): Promise<void> {
  const stat = await lstat(path);
  const matches = kind === 'directory' ? stat.isDirectory() : stat.isFile();
  if (!matches || stat.isSymbolicLink()) throw new Error(`${path} must be a regular ${kind}`);
  if (typeof process.getuid === 'function' && stat.uid !== process.getuid()) {
    throw new Error(`${path} must be owned by the current user`);
  }
  const expected = kind === 'directory' ? 0o700 : 0o600;
  if ((stat.mode & 0o777) !== expected) {
    throw new Error(`${path} must have mode ${expected.toString(8).padStart(4, '0')}`);
  }
}

function parseSession(raw: string): Session {
  const value = JSON.parse(raw) as Partial<Session>;
  if (
    value.version !== 1 ||
    typeof value.id !== 'string' ||
    typeof value.createdAt !== 'string' ||
    typeof value.updatedAt !== 'string' ||
    typeof value.model !== 'string' ||
    !Array.isArray(value.messages) ||
    !value.messages.every(
      (message) =>
        (message.role === 'user' || message.role === 'assistant') &&
        typeof message.content === 'string',
    )
  ) {
    throw new Error('Invalid OpenRouter agent session file');
  }
  validSessionId(value.id);
  return value as Session;
}

export class SessionStore {
  constructor(readonly dir = defaultSessionDir()) {}

  private async ensureDir(): Promise<void> {
    await mkdir(this.dir, { recursive: true, mode: 0o700 });
    await assertPrivate(this.dir, 'directory');
  }

  private path(id: string): string {
    validSessionId(id);
    return join(this.dir, `${id}.json`);
  }

  async save(session: Session): Promise<void> {
    await this.ensureDir();
    validSessionId(session.id);
    const target = this.path(session.id);
    const temporary = join(this.dir, `.${basename(target)}.${randomUUID()}.tmp`);
    const handle = await open(temporary, 'wx', 0o600);
    try {
      await handle.writeFile(`${JSON.stringify(session, null, 2)}
`, 'utf8');
      await handle.sync();
    } finally {
      await handle.close();
    }
    try {
      await rename(temporary, target);
      await assertPrivate(target, 'file');
    } catch (error) {
      await rm(temporary, { force: true });
      throw error;
    }
  }

  async load(id: string): Promise<Session> {
    await this.ensureDir();
    const path = this.path(id);
    await assertPrivate(path, 'file');
    return parseSession(await readFile(path, 'utf8'));
  }

  async list(): Promise<Array<Pick<Session, 'id' | 'updatedAt' | 'model'>>> {
    await this.ensureDir();
    const entries = (await readdir(this.dir))
      .filter((entry) => entry.endsWith('.json'))
      .sort()
      .reverse();
    const sessions = [];
    for (const entry of entries) {
      const session = await this.load(entry.slice(0, -5));
      sessions.push({ id: session.id, updatedAt: session.updatedAt, model: session.model });
    }
    return sessions;
  }
}

export function createSession(model: string): Session {
  const now = new Date().toISOString();
  return {
    version: 1,
    id: `${now.replace(/[:.]/g, '-')}-${randomUUID().slice(0, 8)}`,
    createdAt: now,
    updatedAt: now,
    model,
    messages: [],
  };
}
