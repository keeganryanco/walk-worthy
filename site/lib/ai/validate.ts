import { DailyJourneyPackage } from "./types";
import { normalizeReference } from "./scripture";

function cleanText(value: unknown, maxLength: number): string {
  if (typeof value !== "string") {
    return "";
  }
  return value.trim().slice(0, maxLength);
}

function normalizeChip(value: unknown): string {
  const cleaned = cleanText(value, 80).replace(/[^\p{L}\p{N}\s'-]/gu, " ");
  if (!cleaned) return "";
  const compact = cleaned.replace(/\s+/g, " ").trim();
  const words = compact.split(" ").slice(0, 4);
  return words.join(" ");
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

export function parseAndNormalizePackage(rawText: string): DailyJourneyPackage | null {
  const parsed = extractJSON(rawText);
  if (!parsed || typeof parsed !== "object") {
    return null;
  }

  return normalizePackageFromObject(parsed as Record<string, unknown>);
}

export function normalizePackageFromObject(source: Record<string, unknown>): DailyJourneyPackage | null {
  const suggestedRaw = Array.isArray(source.suggestedSteps) ? source.suggestedSteps : [];
  const suggested = suggestedRaw
    .map((item) => normalizeChip(item))
    .filter(Boolean)
    .slice(0, 4);

  const completionRaw =
    source.completionSuggestion && typeof source.completionSuggestion === "object"
      ? (source.completionSuggestion as Record<string, unknown>)
      : {};
  const confidenceRaw = typeof completionRaw.confidence === "number" ? completionRaw.confidence : 0;
  const confidence = Math.min(1, Math.max(0, confidenceRaw));

  const normalized: DailyJourneyPackage = {
    reflectionThought: cleanText(source.reflectionThought, 240),
    scriptureReference: normalizeReference(cleanText(source.scriptureReference, 80)),
    scriptureParaphrase: cleanText(source.scriptureParaphrase, 320),
    prayer: cleanText(source.prayer, 360),
    smallStepQuestion: cleanText(source.smallStepQuestion, 120) || "What small step could you take today?",
    suggestedSteps: suggested.length > 0 ? suggested : ["Pray 5 minutes", "Do one task", "Text an update"],
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
