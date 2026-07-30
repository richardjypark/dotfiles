import type { ChatMessages } from '@openrouter/agent';
import type { OpenRouter } from '@openrouter/sdk';
import { z } from 'zod';

import type {
  AgentEvent,
  AgentRunOptions,
  AgentRunResult,
} from './agent.js';
import type { AgentConfig } from './config.js';
import type { ChatMessage } from './session.js';
import type { createTools } from './tools/index.js';

const MAX_TOOL_OUTPUT_CHARS = 100_000;
const MAX_RENDERED_TOOL_OUTPUT_CHARS = 240;

type AgentTools = ReturnType<typeof createTools>;
type AgentTool = AgentTools[number];

interface LocalFunctionTool {
  function: {
    name: string;
    description?: string;
    inputSchema: z.ZodObject;
    requireApproval?: boolean | ((args: Record<string, unknown>, context: {
      numberOfTurns: number;
    }) => boolean | Promise<boolean>);
    execute: (args: Record<string, unknown>) => unknown | Promise<unknown>;
  };
  type: 'function';
}

interface ServerAgentTool {
  _brand: 'server-tool';
  config: { type: string; [key: string]: unknown };
}

interface ChatFunctionTool {
  type: 'function';
  function: {
    name: string;
    description?: string;
    parameters: Record<string, unknown>;
  };
}

type ChatRequestTool = ChatFunctionTool | ServerAgentTool['config'];

interface ChatToolCall {
  id: string;
  type: 'function';
  function: {
    name: string;
    arguments: string;
  };
}

interface ChatStreamToolCall {
  index: number;
  id?: string;
  type?: 'function';
  function?: {
    name?: string;
    arguments?: string;
  };
}

interface ChatUsage {
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
  cost?: number | null;
}

interface ChatStreamChunk {
  error?: { message: string };
  choices: Array<{
    index: number;
    finishReason: string | null;
    delta: {
      content?: string | null;
      reasoning?: string | null;
      reasoningDetails?: unknown[];
      toolCalls?: ChatStreamToolCall[];
    };
  }>;
  usage?: ChatUsage;
}

interface ChatRequest {
  model: string;
  messages: ChatMessages[];
  tools: ChatRequestTool[];
  stream: true;
  streamOptions: { includeUsage: true };
  maxCompletionTokens: number;
  provider: {
    dataCollection: 'deny';
    requireParameters: true;
    allowFallbacks: boolean;
  };
}

type ChatSend = (request: ChatRequest) => Promise<AsyncIterable<ChatStreamChunk>>;

interface PendingToolCall {
  index: number;
  id: string;
  name: string;
  arguments: string;
}

function asServerTool(tool: AgentTool): ServerAgentTool | undefined {
  const candidate = tool as unknown as Partial<ServerAgentTool>;
  return candidate._brand === 'server-tool' && candidate.config
    ? candidate as ServerAgentTool
    : undefined;
}

function asLocalTool(tool: AgentTool): LocalFunctionTool | undefined {
  const candidate = tool as unknown as Partial<LocalFunctionTool>;
  return candidate.type === 'function' && candidate.function
    ? candidate as LocalFunctionTool
    : undefined;
}

function schemaFor(tool: LocalFunctionTool): Record<string, unknown> {
  const schema = z.toJSONSchema(tool.function.inputSchema) as Record<string, unknown>;
  const { $schema: _schemaVersion, ...parameters } = schema;
  return parameters;
}

function toChatTools(tools: AgentTools): ChatRequestTool[] {
  return tools.map((tool) => {
    const serverTool = asServerTool(tool);
    if (serverTool) return serverTool.config;
    const localTool = asLocalTool(tool);
    if (!localTool) throw new Error('Unsupported local tool configuration');
    return {
      type: 'function',
      function: {
        name: localTool.function.name,
        description: localTool.function.description,
        parameters: schemaFor(localTool),
      },
    };
  });
}

function serializeToolResult(result: unknown): string {
  let output: string;
  try {
    output = JSON.stringify(result);
  } catch {
    output = JSON.stringify({ error: 'Tool result could not be serialized safely' });
  }
  if (output === undefined) output = JSON.stringify({ result: null });
  if (output.length <= MAX_TOOL_OUTPUT_CHARS) return output;
  return `${output.slice(0, MAX_TOOL_OUTPUT_CHARS)}… [tool output truncated]`;
}

function renderedToolOutput(output: string): string {
  return output.length > MAX_RENDERED_TOOL_OUTPUT_CHARS
    ? `${output.slice(0, MAX_RENDERED_TOOL_OUTPUT_CHARS)}…`
    : output;
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function emit(options: AgentRunOptions, event: AgentEvent): void {
  options.onEvent?.(event);
}

function normalizedUsage(usage: ChatUsage): NonNullable<AgentRunResult['usage']> {
  return {
    inputTokens: usage.promptTokens,
    outputTokens: usage.completionTokens,
    totalTokens: usage.totalTokens,
    ...(typeof usage.cost === 'number' && { cost: usage.cost }),
  };
}

export class ChatCompletionsAgent {
  private readonly chatTools: ChatRequestTool[];
  private readonly localTools: Map<string, LocalFunctionTool>;

  constructor(
    private readonly config: AgentConfig,
    private readonly agentTools: AgentTools,
    private readonly client: OpenRouter,
    private readonly workspaceRoot: string,
  ) {
    this.chatTools = toChatTools(agentTools);
    this.localTools = new Map(
      agentTools
        .map(asLocalTool)
        .filter((tool): tool is LocalFunctionTool => tool !== undefined)
        .map((tool) => [tool.function.name, tool]),
    );
  }

  async run(messages: ChatMessage[], options: AgentRunOptions): Promise<AgentRunResult> {
    const conversation: ChatMessages[] = [
      {
        role: 'system',
        content: this.config.systemPrompt.replace('{cwd}', this.workspaceRoot),
      },
      ...messages,
    ];
    const cumulativeUsage = {
      inputTokens: 0,
      outputTokens: 0,
      totalTokens: 0,
      cost: 0,
    };
    let sawUsage = false;
    let completeText = '';
    const send = this.client.chat.send.bind(this.client.chat) as unknown as ChatSend;

    for (let turn = 0; turn < this.config.maxSteps; turn += 1) {
      if (options.signal?.aborted) throw new Error('Agent request cancelled');
      const response = await send({
        model: this.config.model,
        messages: conversation,
        tools: this.chatTools,
        stream: true,
        streamOptions: { includeUsage: true },
        maxCompletionTokens: this.config.maxOutputTokens,
        provider: {
          ...this.config.providerRouting,
          allowFallbacks: this.config.allowProviderFallbacks,
        },
      });
      let turnText = '';
      let turnReasoning = '';
      const reasoningDetails: unknown[] = [];
      const pendingCalls = new Map<number, PendingToolCall>();
      let turnUsage: ChatUsage | undefined;

      for await (const chunk of response) {
        if (options.signal?.aborted) throw new Error('Agent request cancelled');
        if (chunk.error) throw new Error(`OpenRouter Chat Completions error: ${chunk.error.message}`);
        if (chunk.usage) turnUsage = chunk.usage;
        const choice = chunk.choices.find((candidate) => candidate.index === 0);
        if (!choice) continue;
        const delta = choice.delta;
        if (delta.content) {
          turnText += delta.content;
          completeText += delta.content;
          emit(options, { type: 'text', delta: delta.content });
        }
        if (delta.reasoning) {
          turnReasoning += delta.reasoning;
          emit(options, { type: 'reasoning', delta: delta.reasoning });
        }
        if (delta.reasoningDetails) reasoningDetails.push(...delta.reasoningDetails);
        for (const toolCall of delta.toolCalls ?? []) {
          const pending = pendingCalls.get(toolCall.index) ?? {
            index: toolCall.index,
            id: '',
            name: '',
            arguments: '',
          };
          if (toolCall.id) pending.id ||= toolCall.id;
          if (toolCall.function?.name) pending.name += toolCall.function.name;
          if (toolCall.function?.arguments) pending.arguments += toolCall.function.arguments;
          pendingCalls.set(toolCall.index, pending);
        }
      }

      if (turnUsage) {
        sawUsage = true;
        const normalized = normalizedUsage(turnUsage);
        cumulativeUsage.inputTokens += normalized.inputTokens ?? 0;
        cumulativeUsage.outputTokens += normalized.outputTokens ?? 0;
        cumulativeUsage.totalTokens += normalized.totalTokens ?? 0;
        cumulativeUsage.cost += normalized.cost ?? 0;
      }

      const toolCalls = [...pendingCalls.values()]
        .sort((left, right) => left.index - right.index)
        .map((call): ChatToolCall => {
          if (!call.id || !call.name) {
            throw new Error('OpenRouter returned an incomplete Chat Completions tool call');
          }
          return {
            id: call.id,
            type: 'function',
            function: { name: call.name, arguments: call.arguments },
          };
        });
      if (toolCalls.length === 0) {
        return {
          text: completeText,
          usage: sawUsage ? cumulativeUsage : undefined,
        };
      }
      if (typeof turnUsage?.cost !== 'number' || !Number.isFinite(turnUsage.cost) || turnUsage.cost < 0) {
        throw new Error('OpenRouter Chat Completions did not report cost; refusing a paid follow-up');
      }
      if (turn + 1 >= this.config.maxSteps) {
        throw new Error('Chat Completions reached the managed step limit before tool execution');
      }
      if (cumulativeUsage.cost >= this.config.maxCostUsd) {
        throw new Error('Chat Completions reached the managed cost limit before tool execution');
      }

      conversation.push({
        role: 'assistant',
        content: turnText || null,
        ...(turnReasoning && { reasoning: turnReasoning }),
        ...(reasoningDetails.length > 0 && { reasoningDetails }),
        toolCalls,
      } as ChatMessages);

      for (const call of toolCalls) {
        if (options.signal?.aborted) throw new Error('Agent request cancelled');
        const output = await this.executeTool(call, turn + 1, options);
        conversation.push({ role: 'tool', toolCallId: call.id, content: output });
      }
    }

    throw new Error('Chat Completions reached the managed step limit');
  }

  private async executeTool(
    call: ChatToolCall,
    numberOfTurns: number,
    options: AgentRunOptions,
  ): Promise<string> {
    const tool = this.localTools.get(call.function.name);
    let rawArguments: unknown = {};
    try {
      rawArguments = call.function.arguments ? JSON.parse(call.function.arguments) : {};
    } catch {
      const output = serializeToolResult({ error: 'Tool arguments were not valid JSON' });
      emit(options, {
        type: 'tool_call',
        name: call.function.name,
        callId: call.id,
        args: {},
      });
      emit(options, {
        type: 'tool_result',
        name: call.function.name,
        callId: call.id,
        output: renderedToolOutput(output),
      });
      return output;
    }
    const displayArguments = rawArguments && typeof rawArguments === 'object' && !Array.isArray(rawArguments)
      ? rawArguments as Record<string, unknown>
      : {};
    emit(options, {
      type: 'tool_call',
      name: call.function.name,
      callId: call.id,
      args: displayArguments,
    });

    if (!tool) {
      const output = serializeToolResult({ error: `Unknown local tool: ${call.function.name}` });
      emit(options, {
        type: 'tool_result',
        name: call.function.name,
        callId: call.id,
        output: renderedToolOutput(output),
      });
      return output;
    }
    const parsed = tool.function.inputSchema.safeParse(rawArguments);
    if (!parsed.success) {
      const output = serializeToolResult({ error: `Invalid arguments for ${call.function.name}` });
      emit(options, {
        type: 'tool_result',
        name: call.function.name,
        callId: call.id,
        output: renderedToolOutput(output),
      });
      return output;
    }

    let approvalRequired = tool.function.requireApproval === true;
    if (typeof tool.function.requireApproval === 'function') {
      approvalRequired = await tool.function.requireApproval(parsed.data, { numberOfTurns });
    }
    if (approvalRequired) {
      let approved = false;
      try {
        approved = await options.approve({
          id: call.id,
          name: call.function.name,
          arguments: parsed.data,
        });
      } catch {
        // An approval-input failure must deny rather than execute the tool.
      }
      if (!approved) {
        const output = serializeToolResult({ error: 'Tool execution denied by user' });
        emit(options, {
          type: 'tool_result',
          name: call.function.name,
          callId: call.id,
          output: renderedToolOutput(output),
        });
        return output;
      }
    }

    let output: string;
    try {
      output = serializeToolResult(await tool.function.execute(parsed.data));
    } catch (error) {
      output = serializeToolResult({ error: errorMessage(error) });
    }
    emit(options, {
      type: 'tool_result',
      name: call.function.name,
      callId: call.id,
      output: renderedToolOutput(output),
    });
    return output;
  }
}
