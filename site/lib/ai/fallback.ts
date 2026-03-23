import { DailyJourneyPackage, JourneyPackageRequest } from "./types";
import { deterministicReference } from "./scripture";

export function fallbackPackage(input: JourneyPackageRequest): DailyJourneyPackage {
  const seed = `${input.journey.id}-${input.dateISO ?? "today"}`;
  const reference = deterministicReference(seed);

  return {
    reflectionThought: "Faith grows through small faithful choices, not perfect days.",
    scriptureReference: reference,
    scriptureParaphrase: "Keep moving forward in what is good. Faithful effort bears fruit in time.",
    prayer:
      "Lord, steady my heart and align my next action with the growth I am asking You for.",
    smallStepQuestion: "What small step could you take today?",
    suggestedSteps: [
      "Pray 5 minutes",
      "Do one task",
      "Text an update"
    ],
    completionSuggestion: {
      shouldPrompt: false,
      reason: "",
      confidence: 0
    }
  };
}
