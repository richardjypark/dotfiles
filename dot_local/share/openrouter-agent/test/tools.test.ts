import assert from 'node:assert/strict';
import { link, mkdir, mkdtemp, readFile, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { toolRequiresApproval } from '@openrouter/agent';

import { createTools, tools } from '../src/tools/index.js';

const localTools = tools.filter((entry) => 'type' in entry && entry.type === 'function');
const byName = new Map(localTools.map((entry) => [entry.function.name, entry.function]));

test('mutating and command tools require SDK-enforced approval', async () => {
  for (const name of ['file_write', 'file_edit', 'shell']) {
    assert.equal(byName.get(name)?.requireApproval, true, `${name} must require approval`);
    assert.equal(
      await toolRequiresApproval(
        { id: `test-${name}`, name, arguments: {} } as never,
        tools,
        { numberOfTurns: 1 } as never,
      ),
      true,
      `${name} must pause under the SDK approval evaluator`,
    );
  }
});

test('read-only local tools do not require approval', () => {
  for (const name of ['file_read', 'glob', 'grep', 'list_dir']) {
    assert.notEqual(byName.get(name)?.requireApproval, true, `${name} should be read-only`);
  }
});

type ExecutableTool = {
  name: string;
  execute: (params: Record<string, unknown>) => Promise<unknown> | unknown;
};

function executableTool(workspace: string, name: string): ExecutableTool {
  const entry = createTools(workspace).find(
    (candidate) => candidate.type === 'function' && candidate.function.name === name,
  );
  assert.ok(entry && entry.type === 'function');
  return entry.function as unknown as ExecutableTool;
}

test('read-only tools omit credential files and private-key material', async () => {
  const workspace = await mkdtemp(join(tmpdir(), 'openrouter-tools-'));
  await mkdir(join(workspace, '.docker'));
  await mkdir(join(workspace, '.config', 'gh'), { recursive: true });
  await writeFile(join(workspace, '.npmrc'), 'registry=https://registry.example/\n');
  await writeFile(join(workspace, '.docker', 'config.json'), '{}\n');
  await writeFile(join(workspace, '.config', 'gh', 'hosts.yml'), 'needle in app credentials\n');
  await writeFile(join(workspace, 'safe.txt'), 'needle in safe source\n');
  await writeFile(
    join(workspace, 'opaque.txt'),
    `-----BEGIN OPENSSH ${'PRIVATE'} KEY-----\nneedle in protected material\n`,
  );

  const fileRead = executableTool(workspace, 'file_read');
  await assert.rejects(() => fileRead.execute({ path: '.npmrc' }), /credential/i);
  await assert.rejects(() => fileRead.execute({ path: '.docker/config.json' }), /credential/i);
  await assert.rejects(() => fileRead.execute({ path: '.config/gh/hosts.yml' }), /credential/i);
  await assert.rejects(() => fileRead.execute({ path: 'opaque.txt' }), /private-key/i);

  const globTool = executableTool(workspace, 'glob');
  const globResult = await globTool.execute({ pattern: '**/*' }) as { files: string[] };
  assert.deepEqual(globResult.files, ['opaque.txt', 'safe.txt']);

  const grepTool = executableTool(workspace, 'grep');
  const grepResult = await grepTool.execute({ pattern: 'needle' }) as { matches: string[] };
  assert.equal(grepResult.matches.length, 1);
  assert.match(grepResult.matches[0] ?? '', /^safe\.txt:1:/);
});

test('glob and write reject paths that escape through parents or symlinks', async () => {
  const parent = await mkdtemp(join(tmpdir(), 'openrouter-boundary-'));
  const workspace = join(parent, 'workspace');
  const outside = join(parent, 'outside.txt');
  await mkdir(workspace);
  await writeFile(outside, 'outside remains unchanged\n');
  await symlink(outside, join(workspace, 'linked.txt'));

  const globTool = executableTool(workspace, 'glob');
  const globResult = await globTool.execute({ pattern: '../*' }) as { files: string[] };
  assert.deepEqual(globResult.files, []);

  const fileWrite = executableTool(workspace, 'file_write');
  await assert.rejects(
    () => fileWrite.execute({ path: 'linked.txt', content: 'overwrite\n' }),
    /symlink/i,
  );
  assert.equal(await readFile(outside, 'utf8'), 'outside remains unchanged\n');
});

test('write and edit reject hard-linked files that also exist outside the workspace', async () => {
  const parent = await mkdtemp(join(tmpdir(), 'openrouter-hardlink-'));
  const workspace = join(parent, 'workspace');
  await mkdir(workspace);

  const outsideWrite = join(parent, 'outside-write.txt');
  await writeFile(outsideWrite, 'outside write remains unchanged\n');
  await link(outsideWrite, join(workspace, 'write-link.txt'));
  const fileWrite = executableTool(workspace, 'file_write');
  await assert.rejects(
    () => fileWrite.execute({ path: 'write-link.txt', content: 'overwrite\n' }),
    /hard link/i,
  );
  assert.equal(await readFile(outsideWrite, 'utf8'), 'outside write remains unchanged\n');

  const outsideEdit = join(parent, 'outside-edit.txt');
  await writeFile(outsideEdit, 'old text remains outside\n');
  await link(outsideEdit, join(workspace, 'edit-link.txt'));
  const fileEdit = executableTool(workspace, 'file_edit');
  await assert.rejects(
    () => fileEdit.execute({
      path: 'edit-link.txt',
      edits: [{ oldText: 'old text', newText: 'new text' }],
    }),
    /hard link/i,
  );
  assert.equal(await readFile(outsideEdit, 'utf8'), 'old text remains outside\n');
});
