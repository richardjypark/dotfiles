import assert from 'node:assert/strict';
import { lstat, mkdtemp, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import { SessionStore, defaultSessionDir } from '../src/session.js';

test('default session path is in external XDG state, never the current worktree', () => {
  const home = '/home/example';
  assert.equal(
    defaultSessionDir({ HOME: home }),
    '/home/example/.local/state/openrouter-agent/sessions',
  );
  assert.equal(
    defaultSessionDir({ HOME: home, XDG_STATE_HOME: '/state/example' }),
    '/state/example/openrouter-agent/sessions',
  );
});

test('session directory and files use private modes and round-trip safely', async () => {
  const root = await mkdtemp(join(tmpdir(), 'openrouter-agent-session-'));
  const store = new SessionStore(join(root, 'sessions'));
  const session = {
    version: 1 as const,
    id: '20260729-test',
    createdAt: '2026-07-29T00:00:00.000Z',
    updatedAt: '2026-07-29T00:00:00.000Z',
    model: 'openai/gpt-5.6-luna',
    messages: [{ role: 'user' as const, content: 'hello' }],
  };
  await store.save(session);

  const dirStat = await lstat(join(root, 'sessions'));
  const filePath = join(root, 'sessions', '20260729-test.json');
  const fileStat = await lstat(filePath);
  assert.equal(dirStat.mode & 0o777, 0o700);
  assert.equal(fileStat.mode & 0o777, 0o600);
  assert.deepEqual(await store.load(session.id), session);
  assert.doesNotMatch(await readFile(filePath, 'utf8'), /OPENROUTER_API_KEY/);
});
