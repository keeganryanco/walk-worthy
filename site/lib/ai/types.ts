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

export const DAILY_JOURNEY_PACKAGE_QUALITY_VERSION = 3;

export interface JourneyArc {
  purpose: string;
  journeyPurpose?: string;
  currentStage: string;
  todayAim?: string;
  nextMovement: string;
  tone: string;
  practicalActionDirection: string;
  recentDayTitles?: string[];
  lastFollowThroughInterpretation?: string;
  specificContextSignals?: string[];
}

export interface ClientTelemetry {
  distinctID?: string;
  appVersion?: string;
  buildNumber?: string;
  platform?: string;
}

export interface AITokenUsage {
  inputTokens?: number;
  outputTokens?: number;
  totalTokens?: number;
}

export interface AIUsageMetrics extends AITokenUsage {
  estimatedCostUSD?: number;
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
  journeyArc?: JourneyArc;
  recentEntries?: Array<{
    createdAt?: string;
    actionStep?: string;
    userReflection?: string;
    scriptureReference?: string;
    completedAt?: string | null;
    followThroughStatus?: "yes" | "partial" | "no";
  }>;
  usedScriptureReferences?: string[];
  followThroughContext?: {
    previousCommitmentText?: string;
    previousFollowThroughStatus?: "yes" | "partial" | "no" | "unanswered";
    daysSinceCommitment?: number;
  };
  cycleCount?: number;
  completionCount?: number;
  recentJourneySignals?: string[];
  dateISO?: string;
  languageCode?: string;
  localeIdentifier?: string;
  telemetry?: ClientTelemetry;
}

export interface DailyJourneyPackage {
  dailyTitle: string;
  reflectionThought: string;
  scriptureReference: string;
  scriptureParaphrase: string;
  prayer: string;
  todayAim?: string;
  smallStepQuestion: string;
  suggestedSteps: string[];
  completionSuggestion: CompletionSuggestion;
  updatedJourneyArc?: JourneyArc;
  qualityVersion?: number;
}

export interface DevotionalCore {
  dailyTitle: string;
  scriptureReference: string;
  scriptureParaphrase: string;
  reflectionThought: string;
  prayer: string;
  todayAim: string;
  updatedJourneyArc: JourneyArc;
}

export interface ActionLayerOutput {
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
  usage?: AIUsageMetrics;
}

export interface JourneyBootstrapRequest {
  name: string;
  prayerIntentText: string;
  goalIntentText?: string;
  reminderWindow: string;
  languageCode?: string;
  localeIdentifier?: string;
  telemetry?: ClientTelemetry;
}

export interface JourneyBootstrapResponse {
  journeyTitle: string;
  journeyCategory: string;
  themeKey: JourneyThemeKey;
  growthFocus: string;
  journeyArc: JourneyArc;
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
  usage?: AIUsageMetrics;
}
