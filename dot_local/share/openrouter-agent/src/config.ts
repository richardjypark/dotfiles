import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { z } from 'zod';

const transportSchema = z.enum(['responses', 'chat-completions']);

const modelProfileSchema = z.object({
  transport: transportSchema,
  allowProviderFallbacks: z.boolean(),
});

const schema = z.object({
  name: z.string().min(1),
  model: z.string().min(1),
  modelProfiles: z.record(z.string().min(1), modelProfileSchema),
  systemPrompt: z.string().min(1),
  maxSteps: z.number().int().positive(),
  maxOutputTokens: z.number().int().positive(),
  maxCostUsd: z.number().positive().finite(),
  toolTimeoutSeconds: z.number().int().positive().max(600),
  providerRouting: z.object({
    dataCollection: z.literal('deny'),
    requireParameters: z.literal(true),
  }),
}).superRefine((config, context) => {
  if (!config.modelProfiles[config.model]) {
    context.addIssue({
      code: 'custom',
      path: ['model'],
      message: 'default model must be present in modelProfiles',
    });
  }
});

type ManagedAgentConfig = z.infer<typeof schema>;
export type AgentTransport = z.infer<typeof transportSchema>;
export type AgentConfig = ManagedAgentConfig & {
  transport: AgentTransport;
  allowProviderFallbacks: boolean;
};

function positiveNumber(value: string, name: string): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new Error(`${name} must be a positive finite number`);
  }
  return parsed;
}

function positiveInteger(value: string, name: string): number {
  const parsed = positiveNumber(value, name);
  if (!Number.isInteger(parsed)) throw new Error(`${name} must be a positive integer`);
  return parsed;
}

function atMostManaged(value: number, managedMaximum: number, name: string): number {
  if (value > managedMaximum) {
    throw new Error(`${name} must not exceed managed maximum ${managedMaximum}`);
  }
  return value;
}

async function managedConfig(): Promise<ManagedAgentConfig> {
  const moduleDir = dirname(fileURLToPath(import.meta.url));
  const candidates = [
    join(moduleDir, '..', 'agent.config.json'),
    join(moduleDir, '..', '..', 'agent.config.json'),
  ];
  let lastError: unknown;
  for (const path of candidates) {
    try {
      return schema.parse(JSON.parse(await readFile(path, 'utf8')));
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
        lastError = error;
        continue;
      }
      throw new Error(`Invalid managed OpenRouter agent config at ${path}`, {
        cause: error,
      });
    }
  }
  throw new Error('Managed OpenRouter agent config was not found', { cause: lastError });
}

export async function loadConfig(env: NodeJS.ProcessEnv = process.env): Promise<AgentConfig> {
  const config = await managedConfig();
  const model = env.OPENROUTER_AGENT_MODEL?.trim() || config.model;
  const profile = config.modelProfiles[model];
  if (!profile) {
    throw new Error(`OPENROUTER_AGENT_MODEL ${JSON.stringify(model)} is not present in managed modelProfiles`);
  }
  const maxSteps = env.OPENROUTER_AGENT_MAX_STEPS
    ? atMostManaged(
      positiveInteger(env.OPENROUTER_AGENT_MAX_STEPS, 'OPENROUTER_AGENT_MAX_STEPS'),
      config.maxSteps,
      'OPENROUTER_AGENT_MAX_STEPS',
    )
    : config.maxSteps;
  const maxOutputTokens = env.OPENROUTER_AGENT_MAX_OUTPUT_TOKENS
    ? atMostManaged(
      positiveInteger(
        env.OPENROUTER_AGENT_MAX_OUTPUT_TOKENS,
        'OPENROUTER_AGENT_MAX_OUTPUT_TOKENS',
      ),
      config.maxOutputTokens,
      'OPENROUTER_AGENT_MAX_OUTPUT_TOKENS',
    )
    : config.maxOutputTokens;
  const maxCostUsd = env.OPENROUTER_AGENT_MAX_COST_USD
    ? atMostManaged(
      positiveNumber(env.OPENROUTER_AGENT_MAX_COST_USD, 'OPENROUTER_AGENT_MAX_COST_USD'),
      config.maxCostUsd,
      'OPENROUTER_AGENT_MAX_COST_USD',
    )
    : config.maxCostUsd;
  return {
    ...config,
    model,
    ...profile,
    maxSteps,
    maxOutputTokens,
    maxCostUsd,
  };
}
