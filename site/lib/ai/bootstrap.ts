import { fallbackPackage } from "./fallback";
import { generateWithGeminiPrompt } from "./providers/gemini";
import { generateWithOpenAIPrompt } from "./providers/openai";
import {
  BootstrapOrchestratedResult,
  JourneyPackageRequest,
  JourneyBootstrapRequest,
  JourneyBootstrapResponse,
  JourneyThemeKey
} from "./types";
import { normalizePackageFromObject } from "./validate";

const THEME_KEYS: JourneyThemeKey[] = [
  "basic",
  "faith",
  "patience",
  "peace",
  "resilience",
  "community",
  "discipline",
  "healing",
  "joy",
  "wisdom"
];

function cleanText(value: unknown, maxLength: number): string {
  if (typeof value !== "string") return "";
  return value.trim().slice(0, maxLength);
}

function extractJSON(raw: string): unknown {
  const trimmed = raw.trim();
  try {
    return JSON.parse(trimmed);
  } catch {
    // continue
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

function fallbackTheme(request: JourneyBootstrapRequest): JourneyThemeKey {
  const text = `${request.prayerIntentText} ${request.goalIntentText}`.toLowerCase();
  if (/(peace|anxiet|worr|calm|rest|fear)/.test(text)) return "peace";
  if (/(resilien|hard|pain|trial|endur|persever)/.test(text)) return "resilience";
  if (/(patien|wait|timing)/.test(text)) return "patience";
  if (/(faith|trust|doubt|belief|god)/.test(text)) return "faith";
  if (/(joy|gratitude|praise|celebr)/.test(text)) return "joy";
  if (/(wisdom|clarity|guidance|direction|decision)/.test(text)) return "wisdom";
  if (/(heal|health|grief|recover)/.test(text)) return "healing";
  if (/(disciplin|habit|focus|consisten)/.test(text)) return "discipline";
  if (/(community|family|friend|relationship|marriage|fellowship)/.test(text)) return "community";
  return "basic";
}

function fallbackBootstrap(request: JourneyBootstrapRequest): JourneyBootstrapResponse {
  const themeKey = fallbackTheme(request);
  const titleSeed = cleanText(request.goalIntentText, 48) || cleanText(request.prayerIntentText, 48) || "First Journey";
  const journeyTitle = titleSeed.length < 4 ? "First Journey" : titleSeed;
  const journeyCategory = cleanText(request.prayerIntentText, 32) || "General";
  const pkg = fallbackPackage({
    profile: {
      prayerFocus: request.prayerIntentText,
      growthGoal: request.goalIntentText,
      reminderWindow: request.reminderWindow
    },
    journey: {
      id: "bootstrap",
      title: journeyTitle,
      category: journeyCategory,
      themeKey
    }
  });

  return {
    journeyTitle,
    journeyCategory,
    themeKey,
    initialMemory: {
      summary: `${journeyTitle}: ${journeyCategory}.`,
      winsSummary: "No completed tends yet.",
      blockersSummary: "No blocker pattern identified yet.",
      preferredTone: "grounded-encouraging"
    },
    initialPackage: pkg
  };
}

function buildBootstrapPrompt(request: JourneyBootstrapRequest): { system: string; user: string } {
  const system = [
    "You are generating initial journey setup for a Christian prayer-and-action app.",
    "Return strict JSON only.",
    "Classify the journey into one themeKey from:",
    THEME_KEYS.join(", "),
    "Create concise, practical initial memory and a daily package.",
    "Suggested step chips must be complete actionable phrases, not fragments.",
    "Use scripture paraphrase only. No translation labels. No copyright-protected direct verse quoting.",
    "Keep tone grounded, sincere, practical, and hopeful."
  ].join(" ");

  const user = JSON.stringify(
    {
      outputSchema: {
        journeyTitle: "string",
        journeyCategory: "string",
        themeKey: "one of fixed theme keys",
        initialMemory: {
          summary: "string",
          winsSummary: "string",
          blockersSummary: "string",
          preferredTone: "string"
        },
        initialPackage: {
          reflectionThought: "string",
          scriptureReference: "string",
          scriptureParaphrase: "string",
          prayer: "string",
          smallStepQuestion: "string",
          suggestedSteps: ["string", "string", "string"],
          completionSuggestion: {
            shouldPrompt: false,
            reason: "string",
            confidence: "number"
          }
        }
      },
      context: request
    },
    null,
    2
  );

  return { system, user };
}

function parseBootstrap(raw: string, request: JourneyBootstrapRequest): JourneyBootstrapResponse | null {
  const parsed = extractJSON(raw);
  if (!parsed || typeof parsed !== "object") return null;
  const source = parsed as Record<string, unknown>;

  const fallback = fallbackBootstrap(request);
  const themeCandidate = cleanText(source.themeKey, 40).toLowerCase() as JourneyThemeKey;
  const themeKey = THEME_KEYS.includes(themeCandidate) ? themeCandidate : fallback.themeKey;

  const normalizationContext: JourneyPackageRequest = {
    profile: {
      prayerFocus: request.prayerIntentText,
      growthGoal: request.goalIntentText,
      reminderWindow: request.reminderWindow
    },
    journey: {
      id: "bootstrap",
      title: cleanText(source.journeyTitle, 60) || fallback.journeyTitle,
      category: cleanText(source.journeyCategory, 40) || fallback.journeyCategory,
      themeKey
    },
    recentJourneySignals: [request.prayerIntentText, request.goalIntentText]
  };

  const packageSource =
    source.initialPackage && typeof source.initialPackage === "object"
      ? (source.initialPackage as Record<string, unknown>)
      : null;
  const normalizedPackage = packageSource ? normalizePackageFromObject(packageSource, normalizationContext) : null;

  return {
    journeyTitle: cleanText(source.journeyTitle, 60) || fallback.journeyTitle,
    journeyCategory: cleanText(source.journeyCategory, 40) || fallback.journeyCategory,
    themeKey,
    initialMemory: {
      summary:
        cleanText((source.initialMemory as Record<string, unknown> | undefined)?.summary, 240) ||
        fallback.initialMemory.summary,
      winsSummary:
        cleanText((source.initialMemory as Record<string, unknown> | undefined)?.winsSummary, 200) ||
        fallback.initialMemory.winsSummary,
      blockersSummary:
        cleanText((source.initialMemory as Record<string, unknown> | undefined)?.blockersSummary, 200) ||
        fallback.initialMemory.blockersSummary,
      preferredTone:
        cleanText((source.initialMemory as Record<string, unknown> | undefined)?.preferredTone, 80) ||
        fallback.initialMemory.preferredTone
    },
    initialPackage: normalizedPackage ?? fallback.initialPackage
  };
}

export async function generateJourneyBootstrap(
  request: JourneyBootstrapRequest
): Promise<BootstrapOrchestratedResult> {
  const { system, user } = buildBootstrapPrompt(request);

  const openAIKey = process.env.OPENAI_API_KEY?.trim();
  const geminiKey = process.env.GEMINI_API_KEY?.trim();

  const candidates: Array<{
    provider: "openai" | "gemini";
    model: string;
    escalated: boolean;
    call: () => Promise<string>;
  }> = [];

  if (openAIKey) {
    const primaryModel = process.env.OPENAI_PRIMARY_MODEL?.trim() || "gpt-5-mini";
    candidates.push({
      provider: "openai",
      model: primaryModel,
      escalated: false,
      call: () => generateWithOpenAIPrompt(system, user, primaryModel, openAIKey)
    });
  }

  if (geminiKey) {
    const primaryModel = process.env.GEMINI_PRIMARY_MODEL?.trim() || "gemini-2.5-flash";
    candidates.push({
      provider: "gemini",
      model: primaryModel,
      escalated: false,
      call: () => generateWithGeminiPrompt(system, user, primaryModel, geminiKey)
    });
  }

  if (openAIKey) {
    const escalationModel = process.env.OPENAI_ESCALATION_MODEL?.trim() || "gpt-5.1";
    candidates.push({
      provider: "openai",
      model: escalationModel,
      escalated: true,
      call: () => generateWithOpenAIPrompt(system, user, escalationModel, openAIKey)
    });
  }

  for (const candidate of candidates) {
    try {
      const raw = await candidate.call();
      const parsed = parseBootstrap(raw, request);
      if (!parsed) continue;
      return {
        bootstrap: parsed,
        provider: candidate.provider,
        model: candidate.model,
        escalated: candidate.escalated,
        fallbackUsed: false
      };
    } catch {
      continue;
    }
  }

  return {
    bootstrap: fallbackBootstrap(request),
    provider: "template",
    model: "local-template",
    escalated: true,
    fallbackUsed: true
  };
}
