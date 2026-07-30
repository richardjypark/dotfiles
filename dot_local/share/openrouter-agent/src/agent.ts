import {
  callModel,
  maxCost,
  stepCountIs,
  type Item,
} from '@openrouter/agent';
import { OpenRouter } from '@openrouter/sdk';

import type { AgentConfig } from './config.js';
import { ChatCompletionsAgent } from './chat-agent.js';
import type { ChatMessage } from './session.js';
import { createTools } from './tools/index.js';

export type AgentEvent =
  | { type: 'text'; delta: string }
  | { type: 'reasoning'; delta: string }
  | { type: 'tool_call'; name: string; callId: string; args: Record<string, unknown> }
  | { type: 'tool_result'; name: string; callId: string; output: string };

export interface ApprovalRequest {
  id: string;
  name: string;
  arguments: Record<string, unknown>;
}

export interface AgentRunOptions {
  onEvent?: (event: AgentEvent) => void;
  approve: (request: ApprovalRequest) => Promise<boolean>;
  signal?: AbortSignal;
}

export interface AgentRunResult {
  text: string;
  usage?: {
    inputTokens?: number;
    outputTokens?: number;
    totalTokens?: number;
    cost?: number;
  };
}

export class OpenRouterAgent {
  private readonly client: OpenRouter;
  private readonly agentTools: ReturnType<typeof createTools>;

  constructor(
    private readonly config: AgentConfig,
    apiKey: string,
    private readonly workspaceRoot: string,
    client?: OpenRouter,
  ) {
    this.client = client ?? new OpenRouter({
      apiKey,
      retryConfig: { strategy: 'none' },
    });
    this.agentTools = createTools(workspaceRoot, config.toolTimeoutSeconds);
  }

  async run(messages: ChatMessage[], options: AgentRunOptions): Promise<AgentRunResult> {
    if (this.config.transport === 'chat-completions') {
      return new ChatCompletionsAgent(
        this.config,
        this.agentTools,
        this.client,
        this.workspaceRoot,
      ).run(messages, options);
    }
    return this.runResponses(messages, options);
  }

  private async runResponses(
    messages: ChatMessage[],
    options: AgentRunOptions,
  ): Promise<AgentRunResult> {
    const callNames = new Map<string, string>();
    const cumulativeUsage = {
      inputTokens: 0,
      outputTokens: 0,
      totalTokens: 0,
      cost: 0,
    };
    let sawUsage = false;
    let approvalNumber = 0;
    const result = callModel(this.client, {
      model: this.config.model,
      instructions: this.config.systemPrompt.replace('{cwd}', this.workspaceRoot),
      input: messages as Item[],
      tools: this.agentTools,
      maxOutputTokens: this.config.maxOutputTokens,
      provider: {
        ...this.config.providerRouting,
        allowFallbacks: this.config.allowProviderFallbacks,
      },
      stopWhen: [stepCountIs(this.config.maxSteps), maxCost(this.config.maxCostUsd)],
      hooks: {
        PermissionRequest: [{
          handler: async ({ toolName, toolInput }) => {
            approvalNumber += 1;
            let accepted = false;
            try {
              accepted = await options.approve({
                id: `approval-${approvalNumber}`,
                name: toolName,
                arguments: toolInput,
              });
            } catch {
              // Approval input failures deny the tool rather than falling through to an SDK pause.
            }
            return accepted
              ? { decision: 'allow' as const }
              : { decision: 'deny' as const, reason: 'Rejected by user' };
          },
        }],
        PostModelCall: [{
          handler: ({ usage }) => {
            if (!usage) return;
            sawUsage = true;
            cumulativeUsage.inputTokens += usage.inputTokens;
            cumulativeUsage.outputTokens += usage.outputTokens;
            cumulativeUsage.totalTokens += usage.totalTokens;
            cumulativeUsage.cost += usage.cost ?? 0;
          },
        }],
      },
    });

    const textByItem = new Map<string, number>();
    for await (const item of result.getItemsStream()) {
      if (options.signal?.aborted) throw new Error('Agent request cancelled');
      if (item.type === 'message') {
        const text = item.content
          ?.filter((content): content is { type: 'output_text'; text: string } => 'text' in content)
          .map((content) => content.text)
          .join('') ?? '';
        const previous = textByItem.get(item.id) ?? 0;
        if (text.length > previous) {
          options.onEvent?.({ type: 'text', delta: text.slice(previous) });
          textByItem.set(item.id, text.length);
        }
      } else if (item.type === 'function_call') {
        callNames.set(item.callId, item.name);
        if (item.status === 'completed') {
          let args: Record<string, unknown> = {};
          try {
            args = item.arguments ? JSON.parse(item.arguments) as Record<string, unknown> : {};
          } catch {
            // The SDK performs schema validation; rendering malformed arguments is best effort only.
          }
          options.onEvent?.({
            type: 'tool_call',
            name: item.name,
            callId: item.callId,
            args,
          });
        }
      } else if (item.type === 'function_call_output') {
        const output = typeof item.output === 'string' ? item.output : JSON.stringify(item.output);
        options.onEvent?.({
          type: 'tool_result',
          name: callNames.get(item.callId) ?? 'unknown',
          callId: item.callId,
          output: output.length > 240 ? `${output.slice(0, 240)}…` : output,
        });
      } else if (item.type === 'reasoning') {
        const summary = item.summary?.map((part: { text: string }) => part.text).join('') ?? '';
        if (summary) options.onEvent?.({ type: 'reasoning', delta: summary });
      }
    }

    const response = await result.getResponse();
    const pending = await result.getPendingToolCalls();
    if (pending.length > 0) throw new Error('Tool approval did not resolve safely');
    if (options.signal?.aborted) throw new Error('Agent request cancelled');
    return {
      text: response.outputText ?? '',
      usage: sawUsage ? cumulativeUsage : undefined,
    };
  }
}
