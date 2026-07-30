import assert from 'node:assert/strict';
import test from 'node:test';

import { OpenRouterAgent } from '../src/agent.js';
import { loadConfig } from '../src/config.js';

test('managed defaults keep OpenRouter explicit, bounded, and privacy constrained', async () => {
  const config = await loadConfig({});
  assert.equal(config.model, 'openai/gpt-5.6-luna');
  assert.equal(config.transport, 'responses');
  assert.equal(config.allowProviderFallbacks, false);
  assert.equal(config.maxSteps, 24);
  assert.equal(config.maxOutputTokens, 4096);
  assert.equal(config.maxCostUsd, 0.25);
  assert.deepEqual(config.providerRouting, {
    dataCollection: 'deny',
    requireParameters: true,
  });
});

test('numeric environment overrides are validated', async () => {
  const config = await loadConfig({
    OPENROUTER_AGENT_MODEL: 'moonshotai/kimi-k3',
    OPENROUTER_AGENT_MAX_STEPS: '8',
    OPENROUTER_AGENT_MAX_OUTPUT_TOKENS: '512',
    OPENROUTER_AGENT_MAX_COST_USD: '0.10',
  });
  assert.equal(config.model, 'moonshotai/kimi-k3');
  assert.equal(config.transport, 'chat-completions');
  assert.equal(config.allowProviderFallbacks, true);
  assert.equal(config.maxSteps, 8);
  assert.equal(config.maxOutputTokens, 512);
  assert.equal(config.maxCostUsd, 0.1);

  await assert.rejects(
    () => loadConfig({ OPENROUTER_AGENT_MAX_COST_USD: 'unlimited' }),
    /positive finite number/,
  );
});

test('unknown model overrides fail closed before request construction', async () => {
  await assert.rejects(
    () => loadConfig({ OPENROUTER_AGENT_MODEL: 'unmanaged/model' }),
    /not present in managed modelProfiles/,
  );
});

test('runtime safety overrides may lower but not raise managed ceilings', async () => {
  await assert.rejects(
    () => loadConfig({ OPENROUTER_AGENT_MAX_STEPS: '25' }),
    /must not exceed managed maximum 24/,
  );
  await assert.rejects(
    () => loadConfig({ OPENROUTER_AGENT_MAX_OUTPUT_TOKENS: '4097' }),
    /must not exceed managed maximum 4096/,
  );
  await assert.rejects(
    () => loadConfig({ OPENROUTER_AGENT_MAX_COST_USD: '0.26' }),
    /must not exceed managed maximum 0.25/,
  );
});

test('the OpenRouter SDK does not retry ambiguous paid requests', async () => {
  const config = await loadConfig({});
  const agent = new OpenRouterAgent(config, 'test-only-placeholder', process.cwd());
  const client = (agent as unknown as {
    client: { _options: { retryConfig: unknown } };
  }).client;
  assert.deepEqual(client._options.retryConfig, { strategy: 'none' });
});
