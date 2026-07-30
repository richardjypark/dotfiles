#!/usr/bin/env node
import { OpenRouterAgent, type ApprovalRequest } from './agent.js';
import { printBanner } from './banner.js';
import { dispatchCommand, type CommandContext } from './commands.js';
import { loadConfig } from './config.js';
import { readBlockInput, readYesNo } from './input.js';
import { Loader } from './loader.js';
import { TuiRenderer } from './renderer.js';
import {
  DEFAULT_ENV_FILE,
  DEFAULT_OPT_IN_MARKER,
  isSecureOptInMarker,
  loadOpenRouterApiKey,
} from './security.js';
import { createSession, defaultSessionDir, SessionStore } from './session.js';
import { assertSafeWorkspaceRoot } from './workspace.js';

const DIM = '\x1b[2m';
const RESET = '\x1b[0m';

function printHelp(): void {
  console.log(`openrouter-agent — explicit paid OpenRouter coding TUI

Usage:
  openrouter-agent             start the interactive TUI
  openrouter-agent --doctor    validate local setup without a network request
  openrouter-agent --demo      render a deterministic offline demo
  openrouter-agent --help      show this help

Environment overrides:
  OPENROUTER_AGENT_MODEL
  OPENROUTER_AGENT_MAX_STEPS
  OPENROUTER_AGENT_MAX_OUTPUT_TOKENS
  OPENROUTER_AGENT_MAX_COST_USD

The API key is read from an already-exported OPENROUTER_API_KEY or from the
user-owned mode-0600 file ${DEFAULT_ENV_FILE}. The value is never printed.
`);
}

async function doctor(): Promise<void> {
  let healthy = true;
  const config = await loadConfig();
  console.log(`config:   ok (${config.model})`);
  console.log(`sessions: ${defaultSessionDir()}`);

  try {
    const enabled = await isSecureOptInMarker();
    console.log(`opt-in:   ${enabled ? `ok (${DEFAULT_OPT_IN_MARKER})` : `disabled (${DEFAULT_OPT_IN_MARKER})`}`);
    healthy &&= enabled;
  } catch (error) {
    healthy = false;
    console.log(`opt-in:   invalid (${error instanceof Error ? error.message : String(error)})`);
  }

  try {
    const loaded = await loadOpenRouterApiKey();
    console.log(`key:      ok (${loaded.source}; value not displayed)`);
  } catch (error) {
    healthy = false;
    console.log(`key:      unavailable (${error instanceof Error ? error.message : String(error)})`);
  }

  console.log('network:  not contacted');
  if (!healthy) process.exitCode = 1;
}

function demo(): void {
  const renderer = new TuiRenderer();
  printBanner('OpenRouter Agent', 'openai/gpt-5.6-luna', process.cwd());
  renderer.handle({ type: 'text', delta: 'I can inspect this workspace and stream an answer.\n' });
  renderer.handle({ type: 'tool_call', name: 'file_read', callId: 'demo-1', args: { path: 'README.md' } });
  renderer.handle({ type: 'tool_result', name: 'file_read', callId: 'demo-1', output: 'README.md read safely' });
  renderer.approval({ id: 'demo-2', name: 'shell', arguments: { command: 'npm test' } });
  console.log(`${DIM}Demo stopped before approval. No key loaded; no network request made.${RESET}`);
}

async function interactive(): Promise<void> {
  if (!(await isSecureOptInMarker())) {
    throw new Error(
      `OpenRouter Agent is disabled. Create ${DEFAULT_OPT_IN_MARKER} with mode 0600, ` +
      'then re-run chezmoi apply to install the optional command.',
    );
  }

  const config = await loadConfig();
  const workspace = process.cwd();
  assertSafeWorkspaceRoot(workspace);
  const loadedKey = await loadOpenRouterApiKey();
  const store = new SessionStore();
  const context: CommandContext = {
    config,
    store,
    session: createSession(config.model),
    totals: { inputTokens: 0, outputTokens: 0, costUsd: 0 },
  };
  await store.save(context.session);

  const agent = new OpenRouterAgent(config, loadedKey.apiKey, workspace);
  const renderer = new TuiRenderer();
  const promptHistory: string[] = [];
  printBanner(config.name, config.model, workspace);
  console.log(`${DIM}credential source: ${loadedKey.source} (value not displayed)${RESET}`);

  for (;;) {
    const input = (await readBlockInput(promptHistory)).trim();
    if (!input) continue;
    promptHistory.push(input);

    if (input.startsWith('/')) {
      try {
        if ((await dispatchCommand(input, context)) === 'exit') break;
      } catch (error) {
        renderer.error(error);
      }
      continue;
    }

    context.session.messages.push({ role: 'user', content: input });
    context.session.updatedAt = new Date().toISOString();
    await store.save(context.session);

    const loader = new Loader();
    let outputStarted = false;
    let result;
    loader.start();
    try {
      result = await agent.run(context.session.messages, {
        onEvent: (event) => {
          if (!outputStarted) {
            outputStarted = true;
            loader.stop();
          }
          renderer.handle(event);
        },
        approve: async (request: ApprovalRequest) => {
          loader.stop();
          renderer.approval(request);
          const approved = await readYesNo();
          loader.start(approved ? 'Running approved tool' : 'Reporting rejection');
          return approved;
        },
      });
    } catch (error) {
      loader.stop();
      renderer.endTurn();
      context.session.messages.pop();
      context.session.updatedAt = new Date().toISOString();
      await store.save(context.session);
      renderer.error(error);
      result = undefined;
    }

    loader.stop();
    renderer.endTurn();
    if (!result) continue;

    context.session.messages.push({ role: 'assistant', content: result.text });
    context.session.updatedAt = new Date().toISOString();
    await store.save(context.session);
    context.totals.inputTokens += result.usage?.inputTokens ?? 0;
    context.totals.outputTokens += result.usage?.outputTokens ?? 0;
    context.totals.costUsd += result.usage?.cost ?? 0;
    console.log(
      `${DIM}${result.usage?.inputTokens ?? 0} in · ${result.usage?.outputTokens ?? 0} out · ` +
      `$${(result.usage?.cost ?? 0).toFixed(6)} reported${RESET}`,
    );
  }

  console.log(`${DIM}Session saved as ${context.session.id}.${RESET}`);
}

async function main(): Promise<void> {
  if (process.argv.includes('--help') || process.argv.includes('-h')) printHelp();
  else if (process.argv.includes('--demo')) demo();
  else if (process.argv.includes('--doctor')) await doctor();
  else await interactive();
}

main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`Error: ${message}`);
  process.exitCode = 1;
});
