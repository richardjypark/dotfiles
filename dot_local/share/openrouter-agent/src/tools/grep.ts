import { execFile } from 'node:child_process';
import { constants } from 'node:fs';
import { open } from 'node:fs/promises';
import { relative } from 'node:path';
import { promisify } from 'node:util';
import { glob } from 'glob';
import { tool } from '@openrouter/agent/tool';
import { z } from 'zod';
import { resolveExistingWorkspacePath } from '../workspace.js';

const execFileAsync = promisify(execFile);
const MAX_FILES = 5000;
const PRIVATE_KEY_HEADER = /-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----/;

async function hasPrivateKeyHeader(path: string): Promise<boolean> {
  const handle = await open(path, constants.O_RDONLY | constants.O_NOFOLLOW);
  try {
    const buffer = Buffer.alloc(8192);
    const { bytesRead } = await handle.read(buffer, 0, buffer.length, 0);
    return PRIVATE_KEY_HEADER.test(buffer.subarray(0, bytesRead).toString('utf8'));
  } finally {
    await handle.close();
  }
}

export function createGrepTool(workspaceRoot: string) {
  return tool({
    name: 'grep',
    description: 'Search UTF-8 file contents with ripgrep inside the launch workspace.',
    inputSchema: z.object({
      pattern: z.string().min(1),
      path: z.string().optional(),
      fileGlob: z.string().optional(),
      ignoreCase: z.boolean().optional(),
    }),
    execute: async ({ pattern, path = '.', fileGlob, ignoreCase = false }) => {
      const searchPath = await resolveExistingWorkspacePath(workspaceRoot, path);
      const candidates = await glob(fileGlob ?? '**/*', {
        cwd: searchPath,
        absolute: true,
        dot: true,
        follow: false,
        nodir: true,
        ignore: ['node_modules/**', '.git/**', '.jj/**'],
      });
      const safeFiles: string[] = [];
      for (const candidate of candidates) {
        if (safeFiles.length >= MAX_FILES) break;
        try {
          const safePath = await resolveExistingWorkspacePath(workspaceRoot, candidate);
          if (!(await hasPrivateKeyHeader(safePath))) {
            safeFiles.push(relative(searchPath, safePath));
          }
        } catch {
          // Escaping, credential, private-key, and disappearing files are intentionally omitted.
        }
      }

      const lines: string[] = [];
      for (let index = 0; index < safeFiles.length && lines.length <= 200; index += 50) {
        const args = [
          '--no-heading',
          '--with-filename',
          '--line-number',
          '--color=never',
          '--max-columns=2000',
          '--max-columns-preview',
        ];
        if (ignoreCase) args.push('-i');
        args.push('--', pattern, ...safeFiles.slice(index, index + 50));
        try {
          const { stdout } = await execFileAsync('rg', args, {
            cwd: searchPath,
            maxBuffer: 1024 * 1024,
            timeout: 30_000,
          });
          lines.push(...stdout.split('\n').filter(Boolean));
        } catch (error) {
          const code = (error as { code?: string | number }).code;
          if (code === 'ENOENT') throw new Error('ripgrep (rg) is required');
          if (code !== '1' && code !== 1) throw error;
        }
      }
      const truncated = lines.length > 200 || candidates.length > MAX_FILES;
      return {
        matches: lines.slice(0, 200),
        total: lines.length,
        ...(truncated && { truncated: true }),
      };
    },
  });
}
