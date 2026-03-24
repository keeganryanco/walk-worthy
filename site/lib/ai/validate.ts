import { DailyJourneyPackage } from "./types";
import { JourneyPackageRequest } from "./types";
import { normalizeReference } from "./scripture";

const CHIP_MIN_WORDS = 2;
const CHIP_MAX_WORDS = 7;
const CHIP_MAX_LENGTH = 80;
const CHIP_LIMIT = 4;
const CHIP_FALLBACK_COUNT = 3;

const DANGLING_ENDINGS = new Set([
  "a",
  "an",
  "and",
  "at",
  "because",
  "for",
  "from",
  "in",
  "into",
  "of",
  "on",
  "or",
  "that",
  "the",
  "to",
  "toward",
  "towards",
  "with"
]);

const LEADING_FRAGMENT_WORDS = new Set([
  "and",
  "because",
  "for",
  "if",
  "or",
  "so",
  "then",
  "to",
  "when",
  "while",
  "with"
]);

const themeChipBank: Record<string, string[]> = {
  basic: ["Pray over one task", "Take one faithful step", "Complete one delayed task"],
  faith: ["Pray with full trust", "Write one trust statement", "Release one control area"],
  patience: ["Wait before reacting", "Choose one slow step", "Finish one lingering task"],
  peace: ["Take five calm breaths", "Pray through one worry", "Silence one distraction"],
  resilience: ["Do one hard thing", "Reframe one setback", "Ask for strength today"],
  community: ["Send one encouragement text", "Pray for one friend", "Schedule one check-in"],
  discipline: ["Set one focused block", "Remove one distraction", "Start before you feel ready"],
  healing: ["Name one honest feeling", "Take one gentle action", "Reach out for support"],
  joy: ["Write three gratitude lines", "Celebrate one small win", "Share one praise update"],
  wisdom: ["Pause and seek wisdom", "Write one wise next step", "Ask trusted counsel today"]
};

const contextualKeywordChips: Array<{ pattern: RegExp; chips: string[] }> = [
  { pattern: /(anx|worr|fear|stress|panic|calm|rest|peace)/i, chips: ["Pray through this worry", "Take five calm breaths"] },
  { pattern: /(focus|disciplin|habit|procrastin|delay|consisten)/i, chips: ["Start one focused block", "Finish one delayed task"] },
  { pattern: /(family|marriage|friend|relationship|team|community)/i, chips: ["Send one honest message", "Pray for this relationship"] },
  { pattern: /(money|financial|budget|debt|career|business|work)/i, chips: ["Review one key number", "Take one work action"] },
  { pattern: /(health|heal|grief|pain|recover|tired)/i, chips: ["Take one healing step", "Rest and pray ten minutes"] }
];

const genericFallbackChips = ["Pray and choose one step", "Take one faithful action", "Write today's next step"];
const FIRST_PERSON_PRAYER_REGEX = /\b(i|i'm|i’ve|i've|i’d|i'll|i’ll|me|my|mine|myself|we|we're|we’ve|we've|we’d|we'll|we’ll|us|our|ours|ourselves)\b/i;
const DISALLOWED_THIRD_PERSON_PRAYER_PHRASES = [
  "the user",
  "this user",
  "for the user",
  "their journey",
  "his journey",
  "her journey"
];
type FollowThroughStatus = "yes" | "partial" | "no" | "unanswered";

function followThroughStatus(input?: JourneyPackageRequest): FollowThroughStatus | undefined {
  const context = (input as (JourneyPackageRequest & {
    followThroughContext?: { previousFollowThroughStatus?: FollowThroughStatus };
  }) | undefined)?.followThroughContext;

  return context?.previousFollowThroughStatus;
}

function cleanText(value: unknown, maxLength: number): string {
  if (typeof value !== "string") {
    return "";
  }
  return value.trim().slice(0, maxLength);
}

function normalizeChip(value: unknown): string {
  const cleaned = cleanText(value, CHIP_MAX_LENGTH).replace(/[^\p{L}\p{N}\s'-]/gu, " ");
  if (!cleaned) return "";

  const compact = cleaned.replace(/\s+/g, " ").trim();
  if (!compact) return "";

  const words = compact.split(" ");
  if (words.length < CHIP_MIN_WORDS || words.length > CHIP_MAX_WORDS) {
    return "";
  }

  const firstWord = words[0]?.toLowerCase() ?? "";
  const lastWord = words[words.length - 1]?.toLowerCase() ?? "";
  if (LEADING_FRAGMENT_WORDS.has(firstWord) || DANGLING_ENDINGS.has(lastWord)) {
    return "";
  }

  if (/[,:;]$/.test(compact) || compact.endsWith("...")) {
    return "";
  }

  return words.join(" ");
}

function dedupeChips(values: string[]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const chip of values) {
    const key = chip.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(chip);
  }
  return result;
}

function contextSignals(input?: JourneyPackageRequest): string {
  if (!input) return "";
  const profile = `${input.profile.prayerFocus} ${input.profile.growthGoal}`;
  const journey = `${input.journey.title} ${input.journey.category}`;
  const recent = (input.recentJourneySignals ?? []).join(" ");
  return `${profile} ${journey} ${recent}`.toLowerCase();
}

function contextualFallbackChips(input?: JourneyPackageRequest): string[] {
  const status = followThroughStatus(input);
  if (status === "partial" || status === "no") {
    return [
      "Take a two minute step",
      "Choose one easier action",
      "Pray then start small"
    ];
  }

  const themeKey = input?.journey.themeKey ?? "basic";
  const chips: string[] = [...(themeChipBank[themeKey] ?? themeChipBank.basic)];

  const signals = contextSignals(input);
  for (const keywordSet of contextualKeywordChips) {
    if (keywordSet.pattern.test(signals)) {
      chips.push(...keywordSet.chips);
    }
  }

  chips.push(...genericFallbackChips);
  const normalized = dedupeChips(chips.map((chip) => normalizeChip(chip)).filter(Boolean));
  return normalized.slice(0, CHIP_FALLBACK_COUNT);
}

function normalizedChips(rawValues: unknown[], input?: JourneyPackageRequest): string[] {
  const generated = dedupeChips(rawValues.map((item) => normalizeChip(item)).filter(Boolean)).slice(0, CHIP_LIMIT);
  const contextual = contextualFallbackChips(input);

  const merged = dedupeChips([...generated, ...contextual]).slice(0, CHIP_LIMIT);
  if (merged.length >= CHIP_FALLBACK_COUNT) {
    return merged;
  }

  const toppedUp = dedupeChips([...merged, ...genericFallbackChips.map((chip) => normalizeChip(chip)).filter(Boolean)]).slice(
    0,
    CHIP_LIMIT
  );
  if (toppedUp.length >= CHIP_FALLBACK_COUNT) {
    return toppedUp;
  }

  return ["Pray and choose one step", "Take one faithful action", "Write today's next step"].slice(0, CHIP_LIMIT);
}

function normalizeFirstPersonPrayer(value: unknown): string {
  const trimmed = cleanText(value, 360);
  if (!trimmed) return "";

  const normalized = trimmed.toLowerCase().replace(/[’`]/g, "'");
  if (DISALLOWED_THIRD_PERSON_PRAYER_PHRASES.some((phrase) => normalized.includes(phrase))) {
    return "";
  }

  return FIRST_PERSON_PRAYER_REGEX.test(normalized) ? trimmed : "";
}

function extractJSON(raw: string): unknown {
  const trimmed = raw.trim();

  try {
    return JSON.parse(trimmed);
  } catch {
    // Try to parse fenced JSON.
  }

  const fenceMatch = trimmed.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  if (fenceMatch?.[1]) {
    try {
      return JSON.parse(fenceMatch[1]);
    } catch {
      return null;
    }
  }

  return null;
}

export function parseAndNormalizePackage(rawText: string, input?: JourneyPackageRequest): DailyJourneyPackage | null {
  const parsed = extractJSON(rawText);
  if (!parsed || typeof parsed !== "object") {
    return null;
  }

  return normalizePackageFromObject(parsed as Record<string, unknown>, input);
}

export function normalizePackageFromObject(
  source: Record<string, unknown>,
  input?: JourneyPackageRequest
): DailyJourneyPackage | null {
  const suggestedRaw = Array.isArray(source.suggestedSteps) ? source.suggestedSteps : [];
  const suggested = normalizedChips(suggestedRaw, input);

  const completionRaw =
    source.completionSuggestion && typeof source.completionSuggestion === "object"
      ? (source.completionSuggestion as Record<string, unknown>)
      : {};
  const confidenceRaw = typeof completionRaw.confidence === "number" ? completionRaw.confidence : 0;
  const confidence = Math.min(1, Math.max(0, confidenceRaw));

  const status = followThroughStatus(input);
  const defaultQuestion =
    status === "partial" || status === "no"
      ? "What is one small step you can realistically finish today?"
      : "What small step could you take today?";

  const normalized: DailyJourneyPackage = {
    reflectionThought: cleanText(source.reflectionThought, 240),
    scriptureReference: normalizeReference(cleanText(source.scriptureReference, 80)),
    scriptureParaphrase: cleanText(source.scriptureParaphrase, 320),
    prayer: normalizeFirstPersonPrayer(source.prayer),
    smallStepQuestion: cleanText(source.smallStepQuestion, 120) || defaultQuestion,
    suggestedSteps: suggested,
    completionSuggestion: {
      shouldPrompt: completionRaw.shouldPrompt === true,
      reason: cleanText(completionRaw.reason, 220),
      confidence
    }
  };

  if (!normalized.reflectionThought || !normalized.scriptureParaphrase || !normalized.prayer) {
    return null;
  }

  return normalized;
}
