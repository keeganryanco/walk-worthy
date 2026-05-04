import type { AITokenUsage, AIProvider } from "./types";

function sanitizeModelForEnv(model: string): string {
  return model
    .trim()
    .replace(/[^a-zA-Z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .toUpperCase();
}

function numberFromEnv(value: string | undefined): number | undefined {
  if (!value) return undefined;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) return undefined;
  return parsed;
}

const DEFAULT_RATE_PER_1M: Record<string, { input: number; output: number }> = {
  "openai:gpt-5.1": { input: 1.25, output: 10 },
  "openai:gpt-5.2": { input: 1.75, output: 14 },
  "openai:gpt-5.4": { input: 2.5, output: 15 },
  "openai:gpt-5.5": { input: 5, output: 30 }
};

function resolveRatePer1M(provider: AIProvider, model: string, kind: "INPUT" | "OUTPUT"): number | undefined {
  if (provider === "template") return 0;

  const providerKey = provider.toUpperCase();
  const modelKey = sanitizeModelForEnv(model);

  const modelSpecific = numberFromEnv(process.env[`${providerKey}_${modelKey}_${kind}_COST_PER_1M_TOKENS`]);
  if (typeof modelSpecific === "number") return modelSpecific;

  const providerDefault = numberFromEnv(process.env[`${providerKey}_${kind}_COST_PER_1M_TOKENS`]);
  if (typeof providerDefault === "number") return providerDefault;

  const defaultRate = DEFAULT_RATE_PER_1M[`${provider}:${model}`];
  if (defaultRate) {
    return kind === "INPUT" ? defaultRate.input : defaultRate.output;
  }

  return undefined;
}

export function estimateCostUSD(provider: AIProvider, model: string, usage?: AITokenUsage): number | undefined {
  if (!usage) return undefined;

  const inputTokens = usage.inputTokens ?? 0;
  const outputTokens = usage.outputTokens ?? 0;
  if (inputTokens <= 0 && outputTokens <= 0) return 0;

  const inputRate = resolveRatePer1M(provider, model, "INPUT");
  const outputRate = resolveRatePer1M(provider, model, "OUTPUT");
  if (typeof inputRate !== "number" || typeof outputRate !== "number") {
    return undefined;
  }

  const inputCost = (inputTokens / 1_000_000) * inputRate;
  const outputCost = (outputTokens / 1_000_000) * outputRate;
  return Number((inputCost + outputCost).toFixed(8));
}
