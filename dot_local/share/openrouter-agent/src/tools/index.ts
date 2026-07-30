import { serverTool } from '@openrouter/agent';
import { createFileEditTool } from './file-edit.js';
import { createFileReadTool } from './file-read.js';
import { createFileWriteTool } from './file-write.js';
import { createGlobTool } from './glob.js';
import { createGrepTool } from './grep.js';
import { createListDirTool } from './list-dir.js';
import { createShellTool } from './shell.js';

export function createTools(workspaceRoot: string, toolTimeoutSeconds = 120) {
  return [
    createFileReadTool(workspaceRoot),
    createFileWriteTool(workspaceRoot),
    createFileEditTool(workspaceRoot),
    createGlobTool(workspaceRoot),
    createGrepTool(workspaceRoot),
    createListDirTool(workspaceRoot),
    createShellTool(workspaceRoot, toolTimeoutSeconds),
    serverTool({ type: 'openrouter:web_search' }),
    serverTool({ type: 'openrouter:datetime', parameters: { timezone: 'UTC' } }),
  ] as const;
}

export const tools = createTools(process.cwd());
