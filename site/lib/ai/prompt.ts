import { JourneyPackageRequest } from "./types";
import { APPROVED_SCRIPTURE_REFERENCES } from "./scripture";

export function buildPrompt(input: JourneyPackageRequest): { system: string; user: string } {
  const system = [
    "You generate one daily Christian prayer-action package for an iOS app.",
    "Respond with strict JSON only, no markdown, no prose outside JSON.",
    "Do not claim supernatural guarantees, healing guarantees, or financial guarantees.",
    "Use one scripture reference from this allowed list only:",
    APPROVED_SCRIPTURE_REFERENCES.join(", "),
    "Provide scripture paraphrase only; do not mention NIV/ESV/NLT/KJV or any translation label.",
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
        suggestedSteps: ["string", "string", "string"]
      },
      instructions: [
        "Make the reflection concise and specific to the journey.",
        "Prayer should be 1-3 sentences.",
        "Suggested steps should be practical and concrete."
      ],
      context: {
        dateISO: input.dateISO ?? new Date().toISOString(),
        journey: input.journey,
        profile: input.profile,
        memory: input.memory ?? {},
        recentEntries: recent
      }
    },
    null,
    2
  );

  return { system, user };
}
