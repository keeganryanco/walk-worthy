import { JourneyPackageRequest } from "./types";
import { APPROVED_SCRIPTURE_REFERENCES } from "./scripture";

export function buildPrompt(input: JourneyPackageRequest): { system: string; user: string } {
  const followThroughContext =
    (input as JourneyPackageRequest & { followThroughContext?: Record<string, unknown> }).followThroughContext ?? {};

  const system = [
    "You generate one daily Christian prayer-action package for an iOS app.",
    "Respond with strict JSON only, no markdown, no prose outside JSON.",
    "Do not claim supernatural guarantees, healing guarantees, or financial guarantees.",
    "Prefer one scripture reference from this curated list:",
    APPROVED_SCRIPTURE_REFERENCES.join(", "),
    "If needed you may use another canonical Bible reference format (Book Chapter:Verse) that clearly fits context.",
    "Provide scripture paraphrase only; do not mention NIV/ESV/NLT/KJV or any translation label and do not quote copyrighted verse text verbatim.",
    "Keep tone grounded, sincere, and practical."
  ].join(" ");

  const recent = (input.recentEntries ?? [])
    .slice(0, 8)
    .map((entry) => ({
      actionStep: entry.actionStep ?? "",
      userReflection: entry.userReflection ?? "",
      completed: Boolean(entry.completedAt)
    }));

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
        "Prayer should be 1-3 sentences and strictly first-person voice (I/me/my/we/us/our).",
        "Never refer to the user in third person (for example: 'the user', 'they', or by name).",
        "Suggested step chips must be complete, actionable phrases (no fragments), practical, and short (target 3-6 words each).",
        "Never end a suggested chip with dangling words like 'to', 'for', or 'with'.",
        "If followThroughContext.previousFollowThroughStatus is partial or no, lower the next-step difficulty and use gentler wording.",
        "For partial/no follow-through, suggested chips should feel easier and smaller than a normal day.",
        "Only set completionSuggestion.shouldPrompt=true when completionCount is at least 7 and journey signals indicate meaningful progress."
      ],
      context: {
        dateISO: input.dateISO ?? new Date().toISOString(),
        journey: input.journey,
        profile: input.profile,
        memory: input.memory ?? {},
        followThroughContext,
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
