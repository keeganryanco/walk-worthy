import { JourneyPackageRequest } from "./types";
import { APPROVED_SCRIPTURE_REFERENCES } from "./scripture";

function targetLanguage(input: JourneyPackageRequest): { code: "en" | "es" | "pt" | "ko"; label: string; localeIdentifier: string } {
  const languageCode = (input.languageCode ?? "").trim().toLowerCase();
  const localeIdentifier = (input.localeIdentifier ?? "").trim() || "en-US";
  if (languageCode.startsWith("es") || localeIdentifier.toLowerCase().startsWith("es")) {
    return { code: "es", label: "Spanish", localeIdentifier };
  }
  if (languageCode.startsWith("pt") || localeIdentifier.toLowerCase().startsWith("pt")) {
    return { code: "pt", label: "Portuguese (Brazil)", localeIdentifier };
  }
  if (languageCode.startsWith("ko") || localeIdentifier.toLowerCase().startsWith("ko")) {
    return { code: "ko", label: "Korean", localeIdentifier };
  }
  return { code: "en", label: "English", localeIdentifier };
}

export function buildPrompt(input: JourneyPackageRequest): { system: string; user: string } {
  const language = targetLanguage(input);
  const followThroughContext =
    (input as JourneyPackageRequest & { followThroughContext?: Record<string, unknown> }).followThroughContext ?? {};

  const system = [
    "You generate one daily Christian prayer-action package for an iOS app.",
    "Respond with strict JSON only, no markdown, no prose outside JSON.",
    "Do not claim supernatural guarantees, healing guarantees, or financial guarantees.",
    "Do not include inflammatory denominational commentary, sectarian attacks, or arguments about which Christian tradition is superior.",
    "Keep religious language respectful, invitational, and non-coercive. Do not shame, threaten, or pressure the user spiritually.",
    "Prefer one scripture reference from this curated list:",
    APPROVED_SCRIPTURE_REFERENCES.join(", "),
    "If needed you may use another canonical Bible reference format (Book Chapter:Verse) that clearly fits context.",
    "Provide scripture paraphrase only; do not mention NIV/ESV/NLT/KJV or any translation label and do not quote copyrighted verse text verbatim.",
    "Keep tone grounded, sincere, and practical.",
    `Write reflectionThought, scriptureParaphrase, prayer, smallStepQuestion, and suggestedSteps entirely in ${language.label} (${language.code}).`,
    "Do not include translation notes, bilingual output, or language labels."
  ].join(" ");

  const recent = (input.recentEntries ?? [])
    .slice(0, 8)
    .map((entry) => ({
      actionStep: entry.actionStep ?? "",
      userReflection: entry.userReflection ?? "",
      scriptureReference: entry.scriptureReference ?? "",
      completed: Boolean(entry.completedAt),
      followThroughStatus: entry.followThroughStatus ?? ""
    }));

  const usedScriptureReferences = Array.from(
    new Set(
      (input.usedScriptureReferences ?? [])
        .map((value) => value.trim())
        .filter(Boolean)
    )
  ).slice(0, 140);

  const user = JSON.stringify(
    {
      outputSchema: {
        reflectionThought: "string",
        scriptureReference: "string",
        scriptureParaphrase: "string",
        prayer: "string",
        smallStepQuestion: "string",
        suggestedSteps: ["string", "string", "string"],
        completionSuggestion: {
          shouldPrompt: "boolean",
          reason: "string",
          confidence: "number 0..1"
        }
      },
      instructions: [
        "Make the reflection concise and specific to the journey.",
        "reflectionThought should read naturally as a concise reflection statement or gentle directive (not a question).",
        "You may use phrasing like 'Reflect on ...' when it fits, but do not force a fixed opening phrase.",
        "Do not always begin reflectionThought with 'Take a moment to reflect on'.",
        "Do not use first-person pronouns (I/me/my/we/us/our) in reflectionThought.",
        "Keep reflectionThought to 2-4 sentences.",
        "Keep scriptureParaphrase to 1-3 sentences and stay faithful to the cited verse’s central meaning.",
        "Do not blend ideas from unrelated verses into the paraphrase.",
        "ScriptureReference MUST NOT repeat any reference listed in context.usedScriptureReferences.",
        "Prayer should be 1-3 sentences and strictly first-person voice (I/me/my/we/us/our).",
        "Never refer to the user in third person (for example: 'the user', 'they', or by name).",
        "Keep smallStepQuestion to one sentence (ideally under 24 words).",
        "Suggested step chips must be complete, actionable phrases (no fragments), practical, and short (target 3-6 words each).",
        "Never end a suggested chip with dangling words like 'to', 'for', or 'with'.",
        "Advance the journey: use memory, recent entries, and follow-through context to move the focus forward instead of repeating yesterday's angle.",
        "If followThroughContext.previousFollowThroughStatus is partial or no, lower the next-step difficulty and use gentler wording.",
        "If followThroughContext.previousFollowThroughStatus is yes, keep the tone encouraging and increase specificity slightly.",
        "For partial/no follow-through, suggested chips should feel easier and smaller than a normal day.",
        "Only set completionSuggestion.shouldPrompt=true when completionCount is at least 7 and journey signals indicate meaningful progress."
      ],
      context: {
        dateISO: input.dateISO ?? new Date().toISOString(),
        languageCode: language.code,
        localeIdentifier: language.localeIdentifier,
        journey: input.journey,
        profile: input.profile,
        memory: input.memory ?? {},
        followThroughContext,
        usedScriptureReferences,
        recentEntries: recent,
        cycleCount: input.cycleCount ?? 0,
        completionCount: input.completionCount ?? 0,
        recentJourneySignals: input.recentJourneySignals ?? []
      }
    },
    null,
    2
  );

  return { system, user };
}
