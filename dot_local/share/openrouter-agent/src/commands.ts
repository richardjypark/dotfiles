import type { AgentConfig } from './config.js';
import { createSession, type Session, type SessionStore } from './session.js';

const DIM = '\x1b[2m';
const RESET = '\x1b[0m';
const CYAN = '\x1b[36m';

export interface CommandContext {
  config: AgentConfig;
  store: SessionStore;
  session: Session;
  totals: { inputTokens: number; outputTokens: number; costUsd: number };
}

export async function dispatchCommand(input: string, context: CommandContext): Promise<'continue' | 'exit'> {
  const [command, ...args] = input.trim().split(/\s+/);
  switch (command.toLowerCase()) {
    case '/help':
      console.log(`
${CYAN}/new${RESET}       start a new conversation
${CYAN}/save${RESET}      save the current conversation
${CYAN}/resume ID${RESET} resume a saved conversation
${CYAN}/sessions${RESET}  list saved conversations
${CYAN}/model${RESET}     show the active OpenRouter model
${CYAN}/cost${RESET}      show token and reported cost totals
${CYAN}/clear${RESET}     clear the terminal
${CYAN}/exit${RESET}      quit
${DIM}Up/down recalls prompts; Tab completes slash commands.${RESET}
`);
      return 'continue';
    case '/new':
      context.session = createSession(context.config.model);
      await context.store.save(context.session);
      console.log(`New session: ${context.session.id}`);
      return 'continue';
    case '/save':
      context.session.updatedAt = new Date().toISOString();
      await context.store.save(context.session);
      console.log(`Saved session: ${context.session.id}`);
      return 'continue';
    case '/resume': {
      const id = args[0];
      if (!id) {
        console.log('Usage: /resume SESSION_ID');
        return 'continue';
      }
      context.session = await context.store.load(id);
      console.log(`Resumed ${id} (${context.session.messages.length} messages)`);
      return 'continue';
    }
    case '/sessions': {
      const sessions = await context.store.list();
      if (sessions.length === 0) console.log('No saved sessions.');
      for (const session of sessions) {
        console.log(`${session.id}  ${session.updatedAt}  ${session.model}`);
      }
      return 'continue';
    }
    case '/model':
      console.log(context.config.model);
      return 'continue';
    case '/cost':
      console.log(
        `${context.totals.inputTokens} input · ${context.totals.outputTokens} output · ` +
        `$${context.totals.costUsd.toFixed(6)} reported`,
      );
      return 'continue';
    case '/clear':
      process.stdout.write('\x1b[2J\x1b[H');
      return 'continue';
    case '/exit':
      return 'exit';
    default:
      console.log(`Unknown command: ${command}. Use /help.`);
      return 'continue';
  }
}
