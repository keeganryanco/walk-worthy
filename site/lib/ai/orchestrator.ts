import { fallbackActionLayer, fallbackPackage } from "./fallback";
import {
  mergePackageFromCoreAndAction,
  type DevotionalCoreValidationOptions,
  parseAndNormalizeDevotionalCoreBestEffort,
  normalizeDevotionalCoreBestEffortFromObject,
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
  repairNotes?: string,
  validationOptions?: DevotionalCoreValidationOptions
): Promise<{ core: DevotionalCore | null; generated: ProviderGenerationResult; issues: string[] }> {
  const { system, user } = buildDevotionalCorePrompt(input, plan, repairNotes);
  const generated = await generateWithOpenAIPrompt(system, user, model, apiKey, 1800);
  const parsed = parseAndNormalizeDevotionalCoreWithIssues(generated.text, input, validationOptions);
  return { core: parsed.core, generated, issues: parsed.issues };
}

function providerIssue(error: unknown): string {
  const message = error instanceof Error ? error.message : String(error);
  if (/content_filter/i.test(message)) return "provider_content_filter";
  if (/incomplete/i.test(message)) return "provider_incomplete";
  if (/timeout|timed out/i.test(message)) return "provider_timeout";
  if (/rate_limit|429/i.test(message)) return "provider_rate_limit";
  return "provider_exception";
}

async function tryGenerateOpenAICore(
  input: JourneyPackageRequest,
  model: string,
  apiKey: string,
  plan?: DevotionalPlan,
  repairNotes?: string,
  validationOptions?: DevotionalCoreValidationOptions
): Promise<{ core: DevotionalCore | null; generated?: ProviderGenerationResult; issues: string[] }> {
  try {
    return await generateOpenAICore(input, model, apiKey, plan, repairNotes, validationOptions);
  } catch (error) {
    return { core: null, issues: [providerIssue(error)] };
  }
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

function devotionalCoreRepairNotes(
  issues: string[],
  mode: "general" | "sentence-count-rescue",
  options?: DevotionalCoreValidationOptions
): string {
  const failedReasons = issues.length ? ` Validation failures: ${issues.join("; ")}.` : "";
  const relaxedReflectionVoice =
    options?.allowFirstPersonReflection
      ? " For this retry, prioritize coherence and specificity even if reflection voice is first person."
      : "";
  const relaxedSentenceCount =
    options?.minReflectionSentences === 3
      ? " For this retry, reflectionThought may be 3-6 complete sentences if needed to preserve clarity."
      : "";
  const base = [
    "Previous devotional core failed validation.",
    failedReasons,
    relaxedReflectionVoice,
    relaxedSentenceCount,
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

function languageCode(input: JourneyPackageRequest): string {
  const raw = `${input.languageCode ?? input.localeIdentifier ?? ""}`.trim().toLowerCase();
  if (raw.startsWith("ko")) return "ko";
  if (raw.startsWith("ja")) return "ja";
  if (raw.startsWith("es")) return "es";
  if (raw.startsWith("pt")) return "pt";
  if (raw.startsWith("de")) return "de";
  return "en";
}

function coreValidationOptionsForRetry(
  input: JourneyPackageRequest,
  issues: string[],
  stage: "repair" | "sentence-rescue"
): DevotionalCoreValidationOptions | undefined {
  const options: DevotionalCoreValidationOptions = {};
  const language = languageCode(input);
  const hasFirstPersonIssue = issues.some((issue) => issue.includes("reflection uses first person"));
  const hasSentenceCountIssue = issues.some((issue) => issue.includes("reflection must be"));
  const hasSoftQualityIssue = issues.some((issue) =>
    issue.includes("low specificity") ||
    issue.includes("meta-devotional") ||
    issue.includes("overly dense") ||
    issue.includes("vague Christianese") ||
    issue.includes("action language") ||
    issue.includes("generic or missing daily title") ||
    issue.includes("scripture mismatch: reference does not fit")
  );

  if (language === "ko" || language === "ja" || hasFirstPersonIssue) {
    options.allowFirstPersonReflection = true;
  }

  if (stage === "sentence-rescue" || hasSentenceCountIssue) {
    options.minReflectionSentences = 3;
  }

  if (stage === "sentence-rescue" || hasSoftQualityIssue) {
    options.skipQualityGuards = true;
  }

  return Object.keys(options).length ? options : undefined;
}

export async function generateJourneyCore(input: JourneyPackageRequest): Promise<JourneyCoreOrchestratedResult> {
  const openAIKey = process.env.OPENAI_API_KEY?.trim();
  if (!openAIKey) {
    throw new Error("missing_OPENAI_API_KEY");
  }

  const coreModel = devotionalModel();
  const fallbackRepairModel = repairModel();
  const diagnostics: string[] = [];

  const coreAttempt = await tryGenerateOpenAICore(input, coreModel, openAIKey);
  let core = coreAttempt.core;
  let coreUsage = usageWithCost("openai", coreModel, coreAttempt.generated?.usage);
  let escalated = false;
  const firstAttemptRawText = coreAttempt.generated?.text ?? "";

  if (!core) {
    diagnostics.push(`openai_core_failed:${coreAttempt.issues.join("|") || "unknown"}`);
    const repairOptions = coreValidationOptionsForRetry(input, coreAttempt.issues, "repair");
    const repaired = await tryGenerateOpenAICore(
      input,
      fallbackRepairModel,
      openAIKey,
      undefined,
      devotionalCoreRepairNotes(coreAttempt.issues, "general", repairOptions),
      repairOptions
    );
    core = repaired.core;
    coreUsage = combineUsage([coreUsage, usageWithCost("openai", fallbackRepairModel, repaired.generated?.usage)]);
    escalated = true;
    if (!core) {
      diagnostics.push(`openai_core_repair_failed:${repaired.issues.join("|") || "unknown"}`);
      const rescueOptions = coreValidationOptionsForRetry(input, repaired.issues, "sentence-rescue");
      const sentenceRescue = await tryGenerateOpenAICore(
        input,
        fallbackRepairModel,
        openAIKey,
        undefined,
        devotionalCoreRepairNotes(repaired.issues, "sentence-count-rescue", rescueOptions),
        rescueOptions
      );
      core = sentenceRescue.core;
      coreUsage = combineUsage([coreUsage, usageWithCost("openai", fallbackRepairModel, sentenceRescue.generated?.usage)]);
      if (!core) {
        diagnostics.push(`openai_core_sentence_rescue_failed:${sentenceRescue.issues.join("|") || "unknown"}`);
      }
    }
  }

  if (!core) {
    const bestEffortCore = parseAndNormalizeDevotionalCoreBestEffort(firstAttemptRawText, input);
    if (bestEffortCore) {
      return {
        core: bestEffortCore,
        provider: "openai",
        model: `${coreModel}+best-effort-core-fallback`,
        escalated: true,
        usage: coreUsage,
        diagnostics: [...diagnostics, "best_effort_core_from_first_attempt_used"]
      };
    }
    return {
      core: normalizeDevotionalCoreBestEffortFromObject({}, input),
      provider: "openai",
      model: `${coreModel}+best-effort-context-fallback`,
      escalated: true,
      usage: coreUsage,
      diagnostics: [...diagnostics, "best_effort_core_from_context_used"]
    };
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
    return {
      action: fallbackActionLayer(input, input.core),
      provider: "openai",
      model: `${stepModel}+${fallbackRepairModel}+local-action-fallback`,
      escalated: true,
      fallbackUsed: true,
      usage: actionUsage,
      diagnostics: [...diagnostics, "local_action_fallback_used"]
    };
  }

  return {
    action,
    provider: "openai",
    model: escalated ? `${stepModel}+${fallbackRepairModel}` : stepModel,
    escalated,
    fallbackUsed: false,
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
    const repairOptions = coreValidationOptionsForRetry(input, coreAttempt.issues, "repair");
    const repaired = await generateOpenAICore(
      input,
      fallbackRepairModel,
      apiKey,
      undefined,
      devotionalCoreRepairNotes(coreAttempt.issues, "general", repairOptions),
      repairOptions
    );
    core = repaired.core;
    coreUsage = combineUsage([coreUsage, usageWithCost("openai", fallbackRepairModel, repaired.generated.usage)]);
    escalated = true;
    if (!core) {
      diagnostics.push(`openai_core_repair_failed:${repaired.issues.join("|") || "unknown"}`);
      const rescueOptions = coreValidationOptionsForRetry(input, repaired.issues, "sentence-rescue");
      const sentenceRescue = await generateOpenAICore(
        input,
        fallbackRepairModel,
        apiKey,
        undefined,
        devotionalCoreRepairNotes(repaired.issues, "sentence-count-rescue", rescueOptions),
        rescueOptions
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
