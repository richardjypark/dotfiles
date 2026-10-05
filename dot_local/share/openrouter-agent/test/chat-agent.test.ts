import assert from 'node:assert/strict';
import { mkdtemp, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { HTTPClient, OpenRouter } from '@openrouter/sdk';

import { OpenRouterAgent, type AgentEvent, type AgentRunOptions } from '../src/agent.js';
import { ChatCompletionsAgent } from '../src/chat-agent.js';
import type { AgentConfig } from '../src/config.js';
import { createTools } from '../src/tools/index.js';

function config(overrides: Partial<AgentConfig> = {}): AgentConfig {
  return {
    name: 'OpenRouter Reserve Agent',
    model: 'moonshotai/kimi-k3',
    modelProfiles: {
      'openai/gpt-5.6-luna': {
        transport: 'responses',
        allowProviderFallbacks: false,
      },
      'moonshotai/kimi-k3': {
        transport: 'chat-completions',
        allowProviderFallbacks: true,
      },
    },
    transport: 'chat-completions',
    allowProviderFallbacks: true,
    systemPrompt: 'Test system instructions for {cwd}',
    maxSteps: 3,
    maxOutputTokens: 512,
    maxCostUsd: 0.01,
    toolTimeoutSeconds: 120,
    providerRouting: {
      dataCollection: 'deny',
      requireParameters: true,
    },
    ...overrides,
  } as AgentConfig;
}

function options(overrides: Partial<AgentRunOptions> = {}): AgentRunOptions {
  return {
    approve: async () => true,
    ...overrides,
  };
}

function stream(...chunks: Array<Record<string, unknown>>) {
  return (async function* () {
    for (const chunk of chunks) yield chunk;
  })();
}

function responsesReply(id: string, output: Array<Record<string, unknown>>) {
  return {
    id,
    object: 'response',
    created_at: 1,
    completed_at: 2,
    status: 'completed',
    model: 'openai/gpt-5.6-luna',
    output,
    error: null,
    incomplete_details: null,
    instructions: null,
    metadata: null,
    frequency_penalty: null,
    presence_penalty: null,
    temperature: null,
    top_p: null,
    parallel_tool_calls: false,
    tool_choice: 'auto',
    tools: [],
  };
}

test('Chat transport streams output and sends managed routing controls', async () => {
  const requests: Array<Record<string, any>> = [];
  const client = {
    chat: {
      send: async (request: Record<string, any>) => {
        requests.push(request);
        return stream(
          {
            choices: [{ index: 0, finishReason: null, delta: { reasoning: 'think' } }],
          },
          {
            choices: [{ index: 0, finishReason: 'stop', delta: { content: 'hello' } }],
            usage: {
              promptTokens: 12,
              completionTokens: 4,
              totalTokens: 16,
              cost: 0.00002,
            },
          },
        );
      },
    },
  } as unknown as OpenRouter;
  const workspace = await mkdtemp(join(tmpdir(), 'openrouter-chat-'));
  const events: AgentEvent[] = [];
  const agent = new ChatCompletionsAgent(config(), createTools(workspace), client, workspace);

  const result = await agent.run(
    [{ role: 'user', content: 'say hello' }],
    options({ onEvent: (event) => events.push(event) }),
  );

  assert.deepEqual(events, [
    { type: 'reasoning', delta: 'think' },
    { type: 'text', delta: 'hello' },
  ]);
  assert.equal(result.text, 'hello');
  assert.deepEqual(result.usage, {
    inputTokens: 12,
    outputTokens: 4,
    totalTokens: 16,
    cost: 0.00002,
  });
  assert.equal(requests.length, 1);
  assert.equal(requests[0].model, 'moonshotai/kimi-k3');
  assert.equal(requests[0].stream, true);
  assert.deepEqual(requests[0].streamOptions, { includeUsage: true });
  assert.equal(requests[0].maxCompletionTokens, 512);
  assert.deepEqual(requests[0].provider, {
    dataCollection: 'deny',
    requireParameters: true,
    allowFallbacks: true,
  });
  assert.deepEqual(requests[0].messages.slice(0, 2), [
    { role: 'system', content: `Test system instructions for ${workspace}` },
    { role: 'user', content: 'say hello' },
  ]);
  assert.ok(requests[0].tools.some((tool: Record<string, any>) => tool.function?.name === 'file_read'));
  assert.ok(requests[0].tools.some((tool: Record<string, any>) => tool.type === 'openrouter:web_search'));
  assert.ok(requests[0].tools.some((tool: Record<string, any>) => tool.type === 'openrouter:datetime'));
});

test('Chat transport validates and executes a read-only local tool round trip', async () => {
  const requests: Array<Record<string, any>> = [];
  const client = {
    chat: {
      send: async (request: Record<string, any>) => {
        requests.push(request);
        if (requests.length === 1) {
          return stream(
            {
              choices: [{
                index: 0,
                finishReason: null,
                delta: {
                  toolCalls: [{
                    index: 0,
                    id: 'call-1',
                    type: 'function',
                    function: { name: 'list_dir', arguments: '{"path"' },
                  }],
                },
              }],
            },
            {
              choices: [{
                index: 0,
                finishReason: 'tool_calls',
                delta: { toolCalls: [{ index: 0, function: { arguments: ':"."}' } }] },
              }],
              usage: {
                promptTokens: 10,
                completionTokens: 5,
                totalTokens: 15,
                cost: 0.001,
              },
            },
          );
        }
        return stream({
          choices: [{ index: 0, finishReason: 'stop', delta: { content: 'done' } }],
        });
      },
    },
  } as unknown as OpenRouter;
  const workspace = await mkdtemp(join(tmpdir(), 'openrouter-chat-'));
  const events: AgentEvent[] = [];
  const agent = new ChatCompletionsAgent(config(), createTools(workspace), client, workspace);

  await agent.run(
    [{ role: 'user', content: 'inspect the directory' }],
    options({ onEvent: (event) => events.push(event) }),
  );

  assert.ok(events.some((event) => event.type === 'tool_call' && event.name === 'list_dir'));
  assert.ok(events.some((event) => event.type === 'tool_result' && event.name === 'list_dir'));
  assert.equal(requests.length, 2);
  const followUp = requests[1].messages;
  assert.equal(followUp.at(-2).role, 'assistant');
  assert.equal(followUp.at(-2).toolCalls[0].function.name, 'list_dir');
  assert.equal(followUp.at(-1).role, 'tool');
  assert.equal(followUp.at(-1).toolCallId, 'call-1');
  assert.match(followUp.at(-1).content, /"entries"/);
});

test('Chat transport never executes a denied mutating tool', async () => {
  const requests: Array<Record<string, any>> = [];
  const client = {
    chat: {
      send: async (request: Record<string, any>) => {
        requests.push(request);
        if (requests.length === 1) {
          return stream({
            choices: [{
              index: 0,
              finishReason: 'tool_calls',
              delta: {
                toolCalls: [{
                  index: 0,
                  id: 'call-denied',
                  type: 'function',
                  function: {
                    name: 'file_write',
                    arguments: '{"path":"blocked.txt","content":"no"}',
                  },
                }],
              },
            }],
            usage: {
              promptTokens: 10,
              completionTokens: 5,
              totalTokens: 15,
              cost: 0.001,
            },
          });
        }
        return stream({
          choices: [{ index: 0, finishReason: 'stop', delta: { content: 'understood' } }],
        });
      },
    },
  } as unknown as OpenRouter;
  const workspace = await mkdtemp(join(tmpdir(), 'openrouter-chat-'));
  const events: AgentEvent[] = [];
  const agent = new ChatCompletionsAgent(config(), createTools(workspace), client, workspace);

  await agent.run(
    [{ role: 'user', content: 'write a file' }],
    options({
      approve: async () => false,
      onEvent: (event) => events.push(event),
    }),
  );

  await assert.rejects(readFile(join(workspace, 'blocked.txt')), /ENOENT/);
  assert.ok(events.some(
    (event) => event.type === 'tool_result' && event.name === 'file_write' && /denied/i.test(event.output),
  ));
  assert.match(requests[1].messages.at(-1).content, /denied/i);
});

test('Chat transport stops before tool execution after reaching the managed cost limit', async () => {
  let requests = 0;
  let approvalRequests = 0;
  const client = {
    chat: {
      send: async () => {
        requests += 1;
        return stream({
          choices: [{
            index: 0,
            finishReason: 'tool_calls',
            delta: {
              toolCalls: [{
                index: 0,
                id: 'call-over-budget',
                type: 'function',
                function: {
                  name: 'file_write',
                  arguments: '{"path":"blocked-by-budget.txt","content":"no"}',
                },
              }],
            },
          }],
          usage: {
            promptTokens: 10,
            completionTokens: 5,
            totalTokens: 15,
            cost: 0.01,
          },
        });
      },
    },
  } as unknown as OpenRouter;
  const workspace = await mkdtemp(join(tmpdir(), 'openrouter-chat-'));
  const agent = new ChatCompletionsAgent(config(), createTools(workspace), client, workspace);

  await assert.rejects(
    agent.run(
      [{ role: 'user', content: 'write a file' }],
      options({
        approve: async () => {
          approvalRequests += 1;
          return true;
        },
      }),
    ),
    /managed cost limit/,
  );

  assert.equal(requests, 1);
  assert.equal(approvalRequests, 0);
  await assert.rejects(readFile(join(workspace, 'blocked-by-budget.txt')), /ENOENT/);
});

test('Chat transport refuses a paid follow-up when usage cost is missing', async () => {
  let requests = 0;
  let approvalRequests = 0;
  const client = {
    chat: {
      send: async () => {
        requests += 1;
        return stream({
          choices: [{
            index: 0,
            finishReason: 'tool_calls',
            delta: {
              toolCalls: [{
                index: 0,
                id: 'call-no-cost',
                type: 'function',
                function: {
                  name: 'file_write',
                  arguments: '{"path":"blocked-without-cost.txt","content":"no"}',
                },
              }],
            },
          }],
          usage: {
            promptTokens: 10,
            completionTokens: 5,
            totalTokens: 15,
          },
        });
      },
    },
  } as unknown as OpenRouter;
  const workspace = await mkdtemp(join(tmpdir(), 'openrouter-chat-'));
  const agent = new ChatCompletionsAgent(config(), createTools(workspace), client, workspace);

  await assert.rejects(
    agent.run(
      [{ role: 'user', content: 'write a file' }],
      options({
        approve: async () => {
          approvalRequests += 1;
          return true;
        },
      }),
    ),
    /did not report cost/,
  );

  assert.equal(requests, 1);
  assert.equal(approvalRequests, 0);
  await assert.rejects(readFile(join(workspace, 'blocked-without-cost.txt')), /ENOENT/);
});

test('Responses failure is not retried through Chat Completions', async () => {
  let chatCalls = 0;
  const client = new OpenRouter({
    apiKey: 'test-only-placeholder',
    retryConfig: { strategy: 'none' },
    serverURL: 'http://127.0.0.1:1',
    timeoutMs: 500,
  });
  (client.chat as unknown as {
    send: () => Promise<AsyncIterable<Record<string, unknown>>>;
  }).send = async () => {
    chatCalls += 1;
    return stream();
  };
  const workspace = await mkdtemp(join(tmpdir(), 'openrouter-chat-'));
  const agent = new OpenRouterAgent(
    config({
      model: 'openai/gpt-5.6-luna',
      transport: 'responses',
      allowProviderFallbacks: false,
    }),
    'test-only-placeholder',
    workspace,
    client,
  );

  await assert.rejects(agent.run([{ role: 'user', content: 'hello' }], options()));
  assert.equal(chatCalls, 0);
});

// @openrouter/agent 0.8.0 ran this call without approval: the stop rule ended the loop
// before the approval gate. 0.11.0 gates the final-response path.
test('Responses transport gates a tool call that arrives on the step-limit turn', async () => {
  const call = (id: string, path: string) => responsesReply(`resp-${id}`, [{
    type: 'function_call',
    id: `fc-${id}`,
    call_id: `call-${id}`,
    name: 'file_write',
    arguments: JSON.stringify({ path, content: 'no' }),
    status: 'completed',
  }]);
  const replies = [
    call('first', 'approved.txt'),
    call('limit', 'gated.txt'),
    responsesReply('resp-final', [{
      type: 'message',
      id: 'msg-final',
      role: 'assistant',
      status: 'completed',
      content: [{ type: 'output_text', text: 'done', annotations: [] }],
    }]),
  ];
  const client = new OpenRouter({
    apiKey: 'test-only-placeholder',
    retryConfig: { strategy: 'none' },
    httpClient: new HTTPClient({
      fetcher: async () => {
        const reply = replies.shift();
        return new Response(JSON.stringify(reply ?? {}), {
          status: reply ? 200 : 500,
          headers: { 'content-type': 'application/json' },
        });
      },
    }),
  });
  const workspace = await mkdtemp(join(tmpdir(), 'openrouter-chat-'));
  const agent = new OpenRouterAgent(
    config({
      model: 'openai/gpt-5.6-luna',
      transport: 'responses',
      allowProviderFallbacks: false,
      maxSteps: 1,
    }),
    'test-only-placeholder',
    workspace,
    client,
  );
  const approvals: unknown[] = [];

  await agent.run(
    [{ role: 'user', content: 'write two files' }],
    options({
      approve: async (request) => {
        approvals.push(request.arguments.path);
        return request.arguments.path === 'approved.txt';
      },
    }),
  );

  assert.deepEqual(approvals, ['approved.txt', 'gated.txt']);
  assert.equal(await readFile(join(workspace, 'approved.txt'), 'utf8'), 'no');
  await assert.rejects(readFile(join(workspace, 'gated.txt')), /ENOENT/);
});
