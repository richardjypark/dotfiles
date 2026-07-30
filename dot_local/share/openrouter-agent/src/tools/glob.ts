import { glob } from 'glob';
import { relative } from 'node:path';
import { tool } from '@openrouter/agent/tool';
import { z } from 'zod';
import { resolveExistingWorkspacePath } from '../workspace.js';

export function createGlobTool(workspaceRoot: string) {
  return tool({
    name: 'glob',
    description: 'Find files by glob pattern inside the launch workspace.',
    inputSchema: z.object({
      pattern: z.string().min(1),
      path: z.string().optional(),
    }),
    execute: async ({ pattern, path = '.' }) => {
      const cwd = await resolveExistingWorkspacePath(workspaceRoot, path);
      const candidates = await glob(pattern, {
        cwd,
        ignore: ['node_modules/**', '.git/**', '.jj/**'],
        dot: true,
        follow: false,
        nodir: true,
        absolute: true,
      });
      const matches: string[] = [];
      for (const candidate of candidates) {
        try {
          const safePath = await resolveExistingWorkspacePath(workspaceRoot, candidate);
          matches.push(relative(cwd, safePath));
        } catch {
          // Escaping, symlinked-outside, and credential paths are intentionally omitted.
        }
      }
      matches.sort();
      return {
        files: matches.slice(0, 1000),
        total: matches.length,
        ...(matches.length > 1000 && { truncated: true }),
      };
    },
  });
}
