import { DailyJourneyPackage } from "./types";
import { normalizeReference } from "./scripture";

function cleanText(value: unknown, maxLength: number): string {
  if (typeof value !== "string") {
    return "";
  }
  return value.trim().slice(0, maxLength);
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

  const source = parsed as Record<string, unknown>;
  const suggestedRaw = Array.isArray(source.suggestedSteps) ? source.suggestedSteps : [];
  const suggested = suggestedRaw
    .map((item) => cleanText(item, 120))
    .filter(Boolean)
    .slice(0, 4);

  const normalized: DailyJourneyPackage = {
    reflectionThought: cleanText(source.reflectionThought, 240),
    scriptureReference: normalizeReference(cleanText(source.scriptureReference, 80)),
    scriptureParaphrase: cleanText(source.scriptureParaphrase, 320),
    prayer: cleanText(source.prayer, 360),
    smallStepQuestion: cleanText(source.smallStepQuestion, 120) || "What small step could you take today?",
    suggestedSteps: suggested.length > 0 ? suggested : ["Take one specific faithful step for this journey today."]
  };

  if (!normalized.reflectionThought || !normalized.scriptureParaphrase || !normalized.prayer) {
    return null;
  }

  return normalized;
}
