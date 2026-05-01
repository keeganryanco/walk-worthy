import { fallbackPackage } from "./fallback";
import {
  mergePackageFromCoreAndAction,
  devotionalPlanValidationIssues,
  parseAndNormalizeDevotionalPlan,
  parseAndNormalizeActionLayer,
  parseAndNormalizeDevotionalCoreWithIssues,
  parseAndNormalizePackage
} from "./validate";
import type {
  ActionLayerOutput,
  DevotionalCore,
  DevotionalPlan,
  JourneyActionRequest,
  JourneyActionOrchestratedResult,
  JourneyCoreOrchestratedResult,
  JourneyPackageRequest,
  OrchestratedResult,
  AIUsageMetrics,
  AITokenUsage
} from "./types";
import { generateWithOpenAIPrompt } from "./providers/openai";
import { generateWithGemini } from "./providers/gemini";
import { estimateCostUSD } from "./cost";
import { actionModel, devotionalModel, repairModel } from "./modelRouting";
import { buildActionLayerPrompt, buildDevotionalCorePrompt, buildDevotionalPlanPrompt } from "./journeyQualityPrompts";
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
  plan?: DevotionalPlan,
  repairNotes?: string
): Promise<{ core: DevotionalCore | null; generated: ProviderGenerationResult; issues: string[] }> {
  const { system, user } = buildDevotionalCorePrompt(input, plan, repairNotes);
  const generated = await generateWithOpenAIPrompt(system, user, model, apiKey, 1800);
  const parsed = parseAndNormalizeDevotionalCoreWithIssues(generated.text, input);
  return { core: parsed.core, generated, issues: parsed.issues };
}

async function generateOpenAIPlan(
  input: JourneyPackageRequest,
  model: string,
  apiKey: string,
  repairNotes?: string
): Promise<{ plan: DevotionalPlan | null; generated: ProviderGenerationResult; issues: string[] }> {
  const { system, user } = buildDevotionalPlanPrompt(input, repairNotes);
  const generated = await generateWithOpenAIPrompt(system, user, model, apiKey, 1200);
  const parsed = parseAndNormalizeDevotionalPlan(generated.text, input);
  const raw = (() => {
    try {
      return JSON.parse(generated.text) as Record<string, unknown>;
    } catch {
      return null;
    }
  })();
  return {
    plan: parsed,
    generated,
    issues: parsed ? [] : raw ? devotionalPlanValidationIssues(raw, input) : ["invalid devotional plan JSON"]
  };
}

async function generateOpenAIAction(
  input: JourneyPackageRequest,
  core: DevotionalCore,
  model: string,
  apiKey: string,
  repairNotes?: string
): Promise<{ action: ActionLayerOutput | null; generated: ProviderGenerationResult }> {
  const { system, user } = buildActionLayerPrompt(input, core, repairNotes);
  const generated = await generateWithOpenAIPrompt(system, user, model, apiKey, 900);
  return { action: parseAndNormalizeActionLayer(generated.text, input, core), generated };
}

function devotionalCoreRepairNotes(issues: string[], mode: "general" | "sentence-count-rescue"): string {
  const failedReasons = issues.length ? ` Validation failures: ${issues.join("; ")}.` : "";
  const base = [
    "Previous devotional core failed validation.",
    failedReasons,
    "These are private backend diagnostics; do not mention validation, errors, retries, repair, schema, or requirements in any returned field.",
    "Return only the same JSON schema as natural devotional content.",
    "Choose only from the approved Scripture library.",
    "Remove action language from reflection/prayer/scripture.",
    "Make the reflection specific, Scripture-led, and coherent.",
    "Make the prayer concrete."
  ].join(" ");

  if (mode === "sentence-count-rescue") {
    return [
      base,
      "The most important repair is sentence count: reflectionThought must be 4-6 complete sentences.",
      "Do not shorten the devotional point into fragments, and do not add filler just to reach the count.",
      "If the previous reflection was too short, add one plain sentence that deepens the same point.",
      "If the previous reflection was too long, combine or remove only the weakest adjacent sentence while preserving the same point."
    ].join(" ");
  }

  return base;
}

export async function generateJourneyCore(input: JourneyPackageRequest): Promise<JourneyCoreOrchestratedResult> {
  const openAIKey = process.env.OPENAI_API_KEY?.trim();
  if (!openAIKey) {
    throw new Error("missing_OPENAI_API_KEY");
  }

  const coreModel = devotionalModel();
  const fallbackRepairModel = repairModel();
  const diagnostics: string[] = [];

  const coreAttempt = await generateOpenAICore(input, coreModel, openAIKey);
  let core = coreAttempt.core;
  let coreUsage = usageWithCost("openai", coreModel, coreAttempt.generated.usage);
  let escalated = false;

  if (!core) {
    diagnostics.push(`openai_core_failed:${coreAttempt.issues.join("|") || "unknown"}`);
    const repaired = await generateOpenAICore(
      input,
      fallbackRepairModel,
      openAIKey,
      undefined,
      devotionalCoreRepairNotes(coreAttempt.issues, "general")
    );
    core = repaired.core;
    coreUsage = combineUsage([coreUsage, usageWithCost("openai", fallbackRepairModel, repaired.generated.usage)]);
    escalated = true;
    if (!core) {
      diagnostics.push(`openai_core_repair_failed:${repaired.issues.join("|") || "unknown"}`);
      const sentenceRescue = await generateOpenAICore(
        input,
        fallbackRepairModel,
        openAIKey,
        undefined,
        devotionalCoreRepairNotes(repaired.issues, "sentence-count-rescue")
      );
      core = sentenceRescue.core;
      coreUsage = combineUsage([coreUsage, usageWithCost("openai", fallbackRepairModel, sentenceRescue.generated.usage)]);
      if (!core) {
        diagnostics.push(`openai_core_sentence_rescue_failed:${sentenceRescue.issues.join("|") || "unknown"}`);
      }
    }
  }

  if (!core) {
    throw new Error(diagnostics.join("; ") || "openai_core_failed");
  }

  return {
    core,
    provider: "openai",
    model: coreModel,
    escalated,
    usage: coreUsage,
    diagnostics
  };
}

export async function generateJourneyAction(input: JourneyActionRequest): Promise<JourneyActionOrchestratedResult> {
  const openAIKey = process.env.OPENAI_API_KEY?.trim();
  if (!openAIKey) {
    throw new Error("missing_OPENAI_API_KEY");
  }

  const stepModel = actionModel();
  const fallbackRepairModel = repairModel();
  const diagnostics: string[] = [];
  let escalated = false;

  const actionAttempt = await generateOpenAIAction(input, input.core, stepModel, openAIKey);
  let action = actionAttempt.action;
  let actionUsage = usageWithCost("openai", stepModel, actionAttempt.generated.usage);

  if (!action) {
    diagnostics.push("openai_action_failed");
    const repairedAction = await generateOpenAIAction(
      input,
      input.core,
      stepModel,
      openAIKey,
      "Previous action layer failed validation. Make every suggested step relevant to the journey and today's question; include concrete real-world steps when context supports it."
    );
    action = repairedAction.action;
    actionUsage = combineUsage([actionUsage, usageWithCost("openai", stepModel, repairedAction.generated.usage)]);
  }

  if (!action) {
    diagnostics.push("openai_action_repair_failed");
    const escalatedAction = await generateOpenAIAction(
      input,
      input.core,
      fallbackRepairModel,
      openAIKey,
      "Action layer still failed. Use specific, relevant, safe practical steps. Do not return unrelated generic spiritual chips."
    );
    action = escalatedAction.action;
    actionUsage = combineUsage([actionUsage, usageWithCost("openai", fallbackRepairModel, escalatedAction.generated.usage)]);
    escalated = true;
  }

  if (!action) {
    diagnostics.push("openai_action_escalation_failed");
    throw new Error(diagnostics.join("; "));
  }

  return {
    action,
    provider: "openai",
    model: escalated ? `${stepModel}+${fallbackRepairModel}` : stepModel,
    escalated,
    usage: actionUsage,
    diagnostics
  };
}

async function generateWithOpenAIOrchestration(
  input: JourneyPackageRequest,
  apiKey: string
): Promise<OrchestratedResult | null> {
  const coreModel = devotionalModel();
  const fallbackRepairModel = repairModel();
  const stepModel = actionModel();
  const diagnostics: string[] = [];
  let escalated = false;

  const coreAttempt = await generateOpenAICore(input, coreModel, apiKey);
  let core = coreAttempt.core;
  let coreUsage = usageWithCost("openai", coreModel, coreAttempt.generated.usage);

  if (!core) {
    diagnostics.push(`openai_core_failed:${coreAttempt.issues.join("|") || "unknown"}`);
    const repaired = await generateOpenAICore(
      input,
      fallbackRepairModel,
      apiKey,
      undefined,
      devotionalCoreRepairNotes(coreAttempt.issues, "general")
    );
    core = repaired.core;
    coreUsage = combineUsage([coreUsage, usageWithCost("openai", fallbackRepairModel, repaired.generated.usage)]);
    escalated = true;
    if (!core) {
      diagnostics.push(`openai_core_repair_failed:${repaired.issues.join("|") || "unknown"}`);
      const sentenceRescue = await generateOpenAICore(
        input,
        fallbackRepairModel,
        apiKey,
        undefined,
        devotionalCoreRepairNotes(repaired.issues, "sentence-count-rescue")
      );
      core = sentenceRescue.core;
      coreUsage = combineUsage([coreUsage, usageWithCost("openai", fallbackRepairModel, sentenceRescue.generated.usage)]);
      if (!core) {
        diagnostics.push(`openai_core_sentence_rescue_failed:${sentenceRescue.issues.join("|") || "unknown"}`);
      }
    }
  }

  if (!core) {
    throw new Error(diagnostics.join("; "));
  }

  const actionAttempt = await generateOpenAIAction(input, core, stepModel, apiKey);
  let action = actionAttempt.action;
  let actionUsage = usageWithCost("openai", stepModel, actionAttempt.generated.usage);

  if (!action) {
    diagnostics.push("openai_action_failed");
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
    diagnostics.push("openai_action_repair_failed");
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

  if (!action) {
    diagnostics.push("openai_action_escalation_failed");
    throw new Error(diagnostics.join("; "));
  }

  return {
    package: enforceCompletionPromptRules(input, mergePackageFromCoreAndAction(core, action)),
    provider: "openai",
    model: `${coreModel}-core+${stepModel}`,
    escalated,
    fallbackUsed: false,
    usage: combineUsage([coreUsage, actionUsage]),
    diagnostics
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
  const diagnostics: string[] = [];

  if (openAIKey) {
    try {
      const result = await generateWithOpenAIOrchestration(input, openAIKey);
      if (result) return result;
      diagnostics.push("openai_orchestration_returned_null");
    } catch (error) {
      const message = error instanceof Error ? error.message : "unknown";
      diagnostics.push(`openai_exception:${message}`);
      // Fall through to provider fallback and local template.
    }
  } else {
    diagnostics.push("missing_OPENAI_API_KEY");
  }

  try {
    const geminiResult = await generateWithGeminiFallback(input);
    if (geminiResult) return geminiResult;
    diagnostics.push("gemini_unavailable_or_failed");
  } catch (error) {
    const message = error instanceof Error ? error.message : "unknown";
    diagnostics.push(`gemini_exception:${message}`);
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
    },
    diagnostics
  };
}
