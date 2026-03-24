import { DailyJourneyPackage, JourneyPackageRequest } from "./types";
import { deterministicReference } from "./scripture";

type FollowThroughStatus = "yes" | "partial" | "no" | "unanswered";

function followThroughStatus(input: JourneyPackageRequest): FollowThroughStatus | undefined {
  const context = (input as JourneyPackageRequest & {
    followThroughContext?: { previousFollowThroughStatus?: FollowThroughStatus };
  }).followThroughContext;

  return context?.previousFollowThroughStatus;
}

function fallbackChips(input: JourneyPackageRequest): string[] {
  const status = followThroughStatus(input);
  if (status === "partial" || status === "no") {
    return ["Take a two minute step", "Choose one easier action", "Pray then start small"];
  }

  const theme = input.journey.themeKey ?? "basic";
  const byTheme: Record<string, string[]> = {
    basic: ["Pray over one task", "Take one faithful action", "Write today's next step"],
    faith: ["Pray with full trust", "Release one control area", "Take one faith step"],
    patience: ["Choose one slow step", "Wait before reacting", "Finish one lingering task"],
    peace: ["Take five calm breaths", "Pray through one worry", "Silence one distraction"],
    resilience: ["Do one hard thing", "Reframe one setback", "Ask for strength today"],
    community: ["Send one encouragement text", "Pray for one friend", "Schedule one check-in"],
    discipline: ["Set one focused block", "Remove one distraction", "Start before you feel ready"],
    healing: ["Take one gentle action", "Name one honest feeling", "Reach out for support"],
    joy: ["Write three gratitude lines", "Celebrate one small win", "Share one praise update"],
    wisdom: ["Pause and seek wisdom", "Write one wise step", "Ask trusted counsel today"]
  };
  return byTheme[theme] ?? byTheme.basic;
}

export function fallbackPackage(input: JourneyPackageRequest): DailyJourneyPackage {
  const seed = `${input.journey.id}-${input.dateISO ?? "today"}`;
  const reference = deterministicReference(seed);

  return {
    reflectionThought: "Faith grows through small faithful choices, not perfect days.",
    scriptureReference: reference,
    scriptureParaphrase: "Keep moving forward in what is good. Faithful effort bears fruit in time.",
    prayer:
      "Lord, steady my heart and align my next action with the growth I am asking You for.",
    smallStepQuestion:
      followThroughStatus(input) === "partial" ||
      followThroughStatus(input) === "no"
        ? "What is one small step you can realistically finish today?"
        : "What small step could you take today?",
    suggestedSteps: fallbackChips(input),
    completionSuggestion: {
      shouldPrompt: false,
      reason: "",
      confidence: 0
    }
  };
}
