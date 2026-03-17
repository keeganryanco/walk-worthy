export type AIProvider = "openai" | "gemini" | "template";

export interface JourneyPackageRequest {
  profile: {
    prayerFocus: string;
    growthGoal: string;
    reminderWindow?: string;
    blocker?: string;
    supportCadence?: string;
  };
  journey: {
    id: string;
    title: string;
    category: string;
  };
  memory?: {
    summary?: string;
    winsSummary?: string;
    blockersSummary?: string;
    preferredTone?: string;
  };
  recentEntries?: Array<{
    createdAt?: string;
    actionStep?: string;
    userReflection?: string;
    completedAt?: string | null;
  }>;
  dateISO?: string;
}

export interface DailyJourneyPackage {
  reflectionThought: string;
  scriptureReference: string;
  scriptureParaphrase: string;
  prayer: string;
  smallStepQuestion: string;
  suggestedSteps: string[];
}

export interface OrchestratedResult {
  package: DailyJourneyPackage;
  provider: AIProvider;
  model: string;
  escalated: boolean;
  fallbackUsed: boolean;
}
