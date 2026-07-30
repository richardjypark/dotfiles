import assert from 'node:assert/strict';
import { chmod, mkdir, mkdtemp, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import { isSecureOptInMarker, loadOpenRouterApiKey } from '../src/security.js';
import {
  assertSafeWorkspaceRoot,
  resolveExistingWorkspacePath,
  resolveWritableWorkspacePath,
} from '../src/workspace.js';

async function fixture(): Promise<string> {
  return mkdtemp(join(tmpdir(), 'openrouter-agent-security-'));
}

const testKeyLine = 'OPENROUTER_API_' + 'KEY=test-only-placeholder\n';

test('missing opt-in marker is disabled', async () => {
  const dir = await fixture();
  assert.equal(await isSecureOptInMarker(join(dir, 'missing')), false);
});

test('opt-in marker rejects symlinks and group-writable files', async () => {
  const dir = await fixture();
  const target = join(dir, 'target');
  const link = join(dir, 'link');
  await writeFile(target, '', { mode: 0o600 });
  await symlink(target, link);
  await assert.rejects(() => isSecureOptInMarker(link), /regular file/);

  await chmod(target, 0o620);
  await assert.rejects(() => isSecureOptInMarker(target), /writable by group or others/);
});

test('opt-in marker rejects an unsafe or symlinked authorization directory', async () => {
  const dir = await fixture();
  const unsafeDir = join(dir, 'unsafe');
  await mkdir(unsafeDir, { mode: 0o700 });
  const marker = join(unsafeDir, 'openrouter-agent.enabled');
  await writeFile(marker, '', { mode: 0o600 });
  await chmod(unsafeDir, 0o770);
  await assert.rejects(() => isSecureOptInMarker(marker), /writable by group or others/);

  const realDir = join(dir, 'real');
  const linkedDir = join(dir, 'linked');
  await mkdir(realDir, { mode: 0o700 });
  await writeFile(join(realDir, 'openrouter-agent.enabled'), '', { mode: 0o600 });
  await symlink(realDir, linkedDir);
  await assert.rejects(
    () => isSecureOptInMarker(join(linkedDir, 'openrouter-agent.enabled')),
    /directory \(symlinks are rejected\)/,
  );
});

test('secure env loader accepts only a private regular file and returns only the requested key', async () => {
  const dir = await fixture();
  const envFile = join(dir, '.env');
  await writeFile(envFile, `${testKeyLine}UNRELATED=do-not-load\n`, { mode: 0o600 });

  const env: NodeJS.ProcessEnv = {};
  const loaded = await loadOpenRouterApiKey({ env, envFile });
  assert.equal(loaded.apiKey, 'test-only-placeholder');
  assert.equal(loaded.source, envFile);
  assert.equal(env.UNRELATED, undefined);
});

test('secure env loader rejects permissive modes and symlinks', async () => {
  const dir = await fixture();
  const envFile = join(dir, '.env');
  await writeFile(envFile, testKeyLine, { mode: 0o644 });
  await assert.rejects(() => loadOpenRouterApiKey({ env: {}, envFile }), /mode 0600/);

  await chmod(envFile, 0o600);
  const link = join(dir, 'linked.env');
  await symlink(envFile, link);
  await assert.rejects(() => loadOpenRouterApiKey({ env: {}, envFile: link }), /regular file/);
});

test('secure env loader rejects unsafe or symlinked credential directories', async () => {
  const dir = await fixture();
  const unsafeDir = join(dir, 'unsafe');
  await mkdir(unsafeDir, { mode: 0o700 });
  const envFile = join(unsafeDir, '.env');
  await writeFile(envFile, testKeyLine, { mode: 0o600 });
  await chmod(unsafeDir, 0o770);
  await assert.rejects(
    () => loadOpenRouterApiKey({ env: {}, envFile }),
    /writable by group or others/,
  );

  const realDir = join(dir, 'real');
  const linkedDir = join(dir, 'linked');
  await mkdir(realDir, { mode: 0o700 });
  await writeFile(join(realDir, '.env'), testKeyLine, { mode: 0o600 });
  await symlink(realDir, linkedDir);
  await assert.rejects(
    () => loadOpenRouterApiKey({ env: {}, envFile: join(linkedDir, '.env') }),
    /directory \(symlinks are rejected\)/,
  );
});

test('an exported key takes precedence without reading the key file', async () => {
  const dir = await fixture();
  const missing = join(dir, 'missing.env');
  const loaded = await loadOpenRouterApiKey({
    env: { OPENROUTER_API_KEY: 'exported-placeholder' },
    envFile: missing,
  });
  assert.equal(loaded.source, 'environment');
  assert.equal(loaded.apiKey, 'exported-placeholder');
});

test('local file paths refuse credentials even when they are inside the workspace', async () => {
  const dir = await fixture();
  await mkdir(join(dir, '.hermes'), { mode: 0o700 });
  await writeFile(join(dir, '.hermes', '.env'), 'placeholder', { mode: 0o600 });

  await assert.rejects(
    () => resolveExistingWorkspacePath(dir, '.hermes/.env'),
    /credential and secret directories/,
  );
  await assert.rejects(
    () => resolveWritableWorkspacePath(dir, '.env'),
    /environment credential files/,
  );

  for (const relativePath of [
    '.config/gh/hosts.yml',
    '.config/azure/accessTokens.json',
    '.config/gcloud/application_default_credentials.json',
    '.config/rclone/rclone.conf',
    '.local/share/keyrings/login.keyring',
  ]) {
    await assert.rejects(
      () => resolveWritableWorkspacePath(dir, relativePath),
      /credential/,
    );
  }
});

test('the home directory itself is not an allowed interactive workspace', () => {
  const home = '/tmp/openrouter-agent-test-home';
  assert.throws(() => assertSafeWorkspaceRoot(home, home), /home directory/);
  assert.doesNotThrow(() => assertSafeWorkspaceRoot(join(home, 'src', 'project'), home));
});

test('a symlink cannot disguise an unsafe workspace root', async () => {
  const parent = await fixture();
  const home = join(parent, 'home');
  const linkedHome = join(parent, 'linked-home');
  await mkdir(home);
  await symlink(home, linkedHome);

  assert.throws(() => assertSafeWorkspaceRoot(linkedHome, home), /symlink|home directory/);
});
