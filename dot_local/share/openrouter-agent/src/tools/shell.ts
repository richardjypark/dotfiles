import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { tool } from '@openrouter/agent/tool';
import { z } from 'zod';

const execFileAsync = promisify(execFile);

export function createShellTool(workspaceRoot: string, maximumTimeoutSeconds = 120) {
  return tool({
    name: 'shell',
    description: 'Run a shell command in the launch workspace. Requires user approval.',
    inputSchema: z.object({
      command: z.string().min(1),
      timeoutSeconds: z.number().int().positive().optional(),
    }),
    requireApproval: true,
    execute: async ({ command, timeoutSeconds = maximumTimeoutSeconds }) => {
      const timeout = Math.min(timeoutSeconds, maximumTimeoutSeconds) * 1000;
      const shell = process.env.SHELL || '/bin/sh';
      try {
        const { stdout, stderr } = await execFileAsync(shell, ['-lc', command], {
          cwd: workspaceRoot,
          timeout,
          maxBuffer: 512 * 1024,
        });
        const output = `${stdout}${stderr}`.trim();
        const lines = output.split('\n');
        return {
          output: lines.slice(-2000).join('\n'),
          exitCode: 0,
          ...(lines.length > 2000 && { truncated: true }),
        };
      } catch (error) {
        const execError = error as NodeJS.ErrnoException & {
          stdout?: string;
          stderr?: string;
          killed?: boolean;
        };
        return {
          output: `${execError.stdout ?? ''}${execError.stderr ?? ''}`.trim(),
          exitCode: execError.killed ? null : Number(execError.code) || 1,
          ...(execError.killed && { timedOut: true }),
        };
      }
    },
  });
}
