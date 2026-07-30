import { readdir } from 'node:fs/promises';
import { tool } from '@openrouter/agent/tool';
import { z } from 'zod';
import { resolveExistingWorkspacePath } from '../workspace.js';

export function createListDirTool(workspaceRoot: string) {
  return tool({
    name: 'list_dir',
    description: 'List a directory inside the launch workspace.',
    inputSchema: z.object({
      path: z.string().optional(),
    }),
    execute: async ({ path = '.' }) => {
      const safePath = await resolveExistingWorkspacePath(workspaceRoot, path);
      const entries = await readdir(safePath, { withFileTypes: true });
      return {
        entries: entries
          .map((entry) => ({
            name: entry.name,
            type: entry.isDirectory() ? 'directory' : entry.isFile() ? 'file' : 'other',
          }))
          .sort((a, b) => a.name.localeCompare(b.name))
          .slice(0, 1000),
      };
    },
  });
}
