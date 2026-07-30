import { constants } from 'node:fs';
import { open } from 'node:fs/promises';
import { tool } from '@openrouter/agent/tool';
import { z } from 'zod';
import { resolveExistingWorkspacePath } from '../workspace.js';

const MAX_LINES = 2000;
const MAX_LINE_CHARS = 2000;

export function createFileReadTool(workspaceRoot: string) {
  return tool({
    name: 'file_read',
    description: 'Read a UTF-8 file inside the launch workspace with pagination.',
    inputSchema: z.object({
      path: z.string().min(1).describe('Path relative to the launch workspace'),
      offset: z.number().int().positive().optional(),
      limit: z.number().int().positive().max(MAX_LINES).optional(),
    }),
    execute: async ({ path, offset = 1, limit = MAX_LINES }) => {
      const safePath = await resolveExistingWorkspacePath(workspaceRoot, path);
      const handle = await open(safePath, constants.O_RDONLY | constants.O_NOFOLLOW);
      let raw: string;
      try {
        const stat = await handle.stat();
        if (!stat.isFile()) throw new Error('Readable path is not a regular file');
        raw = await handle.readFile('utf8');
      } finally {
        await handle.close();
      }
      if (/-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----/.test(raw)) {
        throw new Error('Local file tools refuse private-key material');
      }
      const lines = raw.split('\n');
      const start = offset - 1;
      const end = Math.min(start + limit, lines.length);
      let longLines = 0;
      const content = lines.slice(start, end).map((line) => {
        if (line.length <= MAX_LINE_CHARS) return line;
        longLines += 1;
        return `${line.slice(0, MAX_LINE_CHARS)}… [line truncated]`;
      });
      return {
        path,
        content: content.join('\n'),
        totalLines: lines.length,
        ...(end < lines.length && { nextOffset: end + 1 }),
        ...(longLines > 0 && { longLinesTruncated: longLines }),
      };
    },
  });
}
