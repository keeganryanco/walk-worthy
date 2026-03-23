export type AIProvider = "openai" | "gemini" | "template";
export type JourneyThemeKey =
  | "basic"
  | "faith"
  | "patience"
  | "peace"
  | "resilience"
  | "community"
  | "discipline"
  | "healing"
  | "joy"
  | "wisdom";

export interface CompletionSuggestion {
  shouldPrompt: boolean;
  reason: string;
  confidence: number;
}

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
    themeKey?: JourneyThemeKey;
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
  cycleCount?: number;
  completionCount?: number;
  recentJourneySignals?: string[];
  dateISO?: string;
}

export interface DailyJourneyPackage {
  reflectionThought: string;
  scriptureReference: string;
  scriptureParaphrase: string;
  prayer: string;
  smallStepQuestion: string;
  suggestedSteps: string[];
  completionSuggestion: CompletionSuggestion;
}

export interface OrchestratedResult {
  package: DailyJourneyPackage;
  provider: AIProvider;
  model: string;
  escalated: boolean;
  fallbackUsed: boolean;
}

export interface JourneyBootstrapRequest {
  name: string;
  prayerIntentText: string;
  goalIntentText: string;
  reminderWindow: string;
}

export interface JourneyBootstrapResponse {
  journeyTitle: string;
  journeyCategory: string;
  themeKey: JourneyThemeKey;
  initialMemory: {
    summary: string;
    winsSummary: string;
    blockersSummary: string;
    preferredTone: string;
  };
  initialPackage: DailyJourneyPackage;
}

export interface BootstrapOrchestratedResult {
  bootstrap: JourneyBootstrapResponse;
  provider: AIProvider;
  model: string;
  escalated: boolean;
  fallbackUsed: boolean;
}
