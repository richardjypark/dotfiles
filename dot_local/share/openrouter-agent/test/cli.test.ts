import assert from 'node:assert/strict';
import { chmod, mkdir, mkdtemp, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const project = resolve(import.meta.dirname, '..');
const cli = join(project, 'src', 'cli.ts');

function runCli(home: string, argument: string) {
  return spawnSync(process.execPath, ['--import', 'tsx', cli, argument], {
    cwd: project,
    env: {
      ...process.env,
      HOME: home,
      XDG_STATE_HOME: join(home, '.local', 'state'),
      HTTPS_PROXY: 'http://127.0.0.1:1',
      HTTP_PROXY: 'http://127.0.0.1:1',
      OPENROUTER_API_KEY: undefined,
    },
    encoding: 'utf8',
    timeout: 15_000,
  });
}

test('offline demo does not require a marker, key, or network', async () => {
  const home = await mkdtemp(join(tmpdir(), 'openrouter-agent-demo-'));
  const result = runCli(home, '--demo');
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /No key loaded; no network request made/);
});

test('doctor validates but never prints the machine-local key', async () => {
  const home = await mkdtemp(join(tmpdir(), 'openrouter-agent-doctor-'));
  const markerDir = join(home, '.config', 'dotfiles');
  const hermesDir = join(home, '.hermes');
  await mkdir(markerDir, { recursive: true, mode: 0o700 });
  await mkdir(hermesDir, { mode: 0o700 });
  const marker = join(markerDir, 'openrouter-agent.enabled');
  const envFile = join(hermesDir, '.env');
  await writeFile(marker, '', { mode: 0o600 });
  await writeFile(envFile, 'OPENROUTER_API_KEY=doctor-test-placeholder\n', { mode: 0o600 });
  await chmod(marker, 0o600);
  await chmod(envFile, 0o600);

  const result = runCli(home, '--doctor');
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /key:\s+ok/);
  assert.match(result.stdout, /network:\s+not contacted/);
  assert.doesNotMatch(result.stdout, /doctor-test-placeholder/);
  assert.doesNotMatch(result.stderr, /doctor-test-placeholder/);
});
