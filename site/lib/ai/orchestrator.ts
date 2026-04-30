import { fallbackPackage } from "./fallback";
import {
  mergePackageFromCoreAndAction,
  parseAndNormalizeActionLayer,
  parseAndNormalizeDevotionalCore,
  parseAndNormalizePackage
} from "./validate";
import { ActionLayerOutput, DevotionalCore, JourneyPackageRequest, OrchestratedResult, AIUsageMetrics, AITokenUsage } from "./types";
import { generateWithOpenAIPrompt } from "./providers/openai";
import { generateWithGemini } from "./providers/gemini";
import { estimateCostUSD } from "./cost";
import { actionModel, devotionalModel, repairModel } from "./modelRouting";
import { buildActionLayerPrompt, buildDevotionalCorePrompt } from "./journeyQualityPrompts";
import type { ProviderGenerationResult } from "./providers/openai";

function enforceCompletionPromptRules(
  input: JourneyPackageRequest,
  parsed: OrchestratedResult["package"]
): OrchestratedResult["package"] {
  const completionCount = typeof input.completionCount === "number" ? input.completionCount : 0;

  if (completionCount < 7 || !parsed.completionSuggestion.shouldPrompt || !parsed.completionSuggestion.reason.trim()) {
    return {
      ...parsed,
      completionSuggestion: {
        shouldPrompt: false,
        reason: "",
        confidence: 0
      }
    };
  }

  return parsed;
}

function usageWithCost(provider: "openai" | "gemini", model: string, usage?: AITokenUsage): AIUsageMetrics | undefined {
  if (!usage) return undefined;
  return {
    ...usage,
    estimatedCostUSD: estimateCostUSD(provider, model, usage)
  };
}

function combineUsage(segments: Array<AIUsageMetrics | undefined>): AIUsageMetrics | undefined {
  const defined = segments.filter(Boolean) as AIUsageMetrics[];
  if (!defined.length) return undefined;
  return {
    inputTokens: defined.reduce((sum, item) => sum + (item.inputTokens ?? 0), 0),
    outputTokens: defined.reduce((sum, item) => sum + (item.outputTokens ?? 0), 0),
    totalTokens: defined.reduce((sum, item) => sum + (item.totalTokens ?? 0), 0),
    estimatedCostUSD: defined.reduce((sum, item) => sum + (item.estimatedCostUSD ?? 0), 0)
  };
}

async function generateOpenAICore(
  input: JourneyPackageRequest,
  model: string,
  apiKey: string,
  repairNotes?: string
): Promise<{ core: DevotionalCore | null; generated: ProviderGenerationResult }> {
  const { system, user } = buildDevotionalCorePrompt(input, repairNotes);
  const generated = await generateWithOpenAIPrompt(system, user, model, apiKey);
  return { core: parseAndNormalizeDevotionalCore(generated.text, input), generated };
}

async function generateOpenAIAction(
  input: JourneyPackageRequest,
  core: DevotionalCore,
  model: string,
  apiKey: string,
  repairNotes?: string
): Promise<{ action: ActionLayerOutput | null; generated: ProviderGenerationResult }> {
  const { system, user } = buildActionLayerPrompt(input, core, repairNotes);
  const generated = await generateWithOpenAIPrompt(system, user, model, apiKey);
  return { action: parseAndNormalizeActionLayer(generated.text, input, core), generated };
}

async function generateWithOpenAIOrchestration(
  input: JourneyPackageRequest,
  apiKey: string
): Promise<OrchestratedResult | null> {
  const coreModel = devotionalModel();
  const fallbackRepairModel = repairModel();
  const stepModel = actionModel();

  const coreAttempt = await generateOpenAICore(input, coreModel, apiKey);
  let core = coreAttempt.core;
  let coreUsage = usageWithCost("openai", coreModel, coreAttempt.generated.usage);
  let escalated = false;

  if (!core) {
    const repaired = await generateOpenAICore(
      input,
      fallbackRepairModel,
      apiKey,
      "Previous devotional core failed validation. Repair sentence counts, remove practical commands from reflection, remove vague Christianese, keep near-quote scripture, and return the same JSON schema."
    );
    core = repaired.core;
    coreUsage = combineUsage([coreUsage, usageWithCost("openai", fallbackRepairModel, repaired.generated.usage)]);
    escalated = true;
  }

  if (!core) return null;

  const actionAttempt = await generateOpenAIAction(input, core, stepModel, apiKey);
  let action = actionAttempt.action;
  let actionUsage = usageWithCost("openai", stepModel, actionAttempt.generated.usage);

  if (!action) {
    const repairedAction = await generateOpenAIAction(
      input,
      core,
      stepModel,
      apiKey,
      "Previous action layer failed validation. Make every suggested step relevant to the journey and today's question; include concrete real-world steps when context supports it."
    );
    action = repairedAction.action;
    actionUsage = combineUsage([actionUsage, usageWithCost("openai", stepModel, repairedAction.generated.usage)]);
  }

  if (!action) {
    const escalatedAction = await generateOpenAIAction(
      input,
      core,
      fallbackRepairModel,
      apiKey,
      "Action layer still failed. Use specific, relevant, safe practical steps. Do not return unrelated generic spiritual chips."
    );
    action = escalatedAction.action;
    actionUsage = combineUsage([actionUsage, usageWithCost("openai", fallbackRepairModel, escalatedAction.generated.usage)]);
    escalated = true;
  }

  if (!action) return null;

  return {
    package: enforceCompletionPromptRules(input, mergePackageFromCoreAndAction(core, action)),
    provider: "openai",
    model: `${coreModel}+${stepModel}`,
    escalated,
    fallbackUsed: false,
    usage: combineUsage([coreUsage, actionUsage])
  };
}

async function generateWithGeminiFallback(input: JourneyPackageRequest): Promise<OrchestratedResult | null> {
  const geminiKey = process.env.GEMINI_API_KEY?.trim();
  if (!geminiKey) return null;
  const model = process.env.GEMINI_PRIMARY_MODEL?.trim() || "gemini-2.5-flash";
  const generated = await generateWithGemini(input, model, geminiKey);
  const parsed = parseAndNormalizePackage(generated.text, input);
  if (!parsed) return null;
  return {
    package: enforceCompletionPromptRules(input, parsed),
    provider: "gemini",
    model,
    escalated: true,
    fallbackUsed: false,
    usage: usageWithCost("gemini", model, generated.usage)
  };
}

export async function generateJourneyPackage(input: JourneyPackageRequest): Promise<OrchestratedResult> {
  const openAIKey = process.env.OPENAI_API_KEY?.trim();

  if (openAIKey) {
    try {
      const result = await generateWithOpenAIOrchestration(input, openAIKey);
      if (result) return result;
    } catch {
      // Fall through to provider fallback and local template.
    }
  }

  try {
    const geminiResult = await generateWithGeminiFallback(input);
    if (geminiResult) return geminiResult;
  } catch {
    // Fall through to local template.
  }

  return {
    package: fallbackPackage(input),
    provider: "template",
    model: "local-template",
    escalated: true,
    fallbackUsed: true,
    usage: {
      inputTokens: 0,
      outputTokens: 0,
      totalTokens: 0,
      estimatedCostUSD: 0
    }
  };
}
