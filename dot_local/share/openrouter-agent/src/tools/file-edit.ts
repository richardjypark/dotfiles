import { constants } from 'node:fs';
import { open } from 'node:fs/promises';
import { tool } from '@openrouter/agent/tool';
import { z } from 'zod';
import { assertOpenedWorkspaceFile, resolveExistingWorkspacePath } from '../workspace.js';

export function createFileEditTool(workspaceRoot: string) {
  return tool({
    name: 'file_edit',
    description: 'Apply exact search-and-replace edits inside the launch workspace. Requires user approval.',
    inputSchema: z.object({
      path: z.string().min(1).describe('Path relative to the launch workspace'),
      edits: z.array(z.object({
        oldText: z.string(),
        newText: z.string(),
      })).min(1),
    }),
    requireApproval: true,
    execute: async ({ path, edits }) => {
      const safePath = await resolveExistingWorkspacePath(workspaceRoot, path);
      const handle = await open(safePath, constants.O_RDWR | constants.O_NOFOLLOW);
      try {
        const stat = await handle.stat();
        if (!stat.isFile()) throw new Error('Editable path is not a regular file');
        await assertOpenedWorkspaceFile(workspaceRoot, safePath, stat);
        let content = await handle.readFile('utf8');
        for (const edit of edits) {
          const occurrences = content.split(edit.oldText).length - 1;
          if (occurrences !== 1) {
            throw new Error(`Expected exactly one match; found ${occurrences}`);
          }
          content = content.replace(edit.oldText, edit.newText);
        }
        await handle.truncate(0);
        await handle.write(content, 0, 'utf8');
      } finally {
        await handle.close();
      }
      return { edited: true, path, replacements: edits.length };
    },
  });
}
