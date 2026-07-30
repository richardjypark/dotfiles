import { constants } from 'node:fs';
import { mkdir, open } from 'node:fs/promises';
import { dirname } from 'node:path';
import { tool } from '@openrouter/agent/tool';
import { z } from 'zod';
import { assertOpenedWorkspaceFile, resolveWritableWorkspacePath } from '../workspace.js';

export function createFileWriteTool(workspaceRoot: string) {
  return tool({
    name: 'file_write',
    description: 'Write a UTF-8 file inside the launch workspace. Requires user approval.',
    inputSchema: z.object({
      path: z.string().min(1).describe('Path relative to the launch workspace'),
      content: z.string(),
    }),
    requireApproval: true,
    execute: async ({ path, content }) => {
      const initialPath = await resolveWritableWorkspacePath(workspaceRoot, path);
      await mkdir(dirname(initialPath), { recursive: true });
      const safePath = await resolveWritableWorkspacePath(workspaceRoot, path);
      const handle = await open(
        safePath,
        constants.O_WRONLY | constants.O_CREAT | constants.O_NOFOLLOW,
        0o600,
      );
      try {
        const stat = await handle.stat();
        await assertOpenedWorkspaceFile(workspaceRoot, safePath, stat);
        await handle.truncate(0);
        await handle.writeFile(content, 'utf8');
      } finally {
        await handle.close();
      }
      return { written: true, path, bytes: Buffer.byteLength(content) };
    },
  });
}
