import { fallbackPackage } from "./fallback";
import { generateWithGeminiPrompt } from "./providers/gemini";
import { generateWithOpenAIPrompt } from "./providers/openai";
import {
  BootstrapOrchestratedResult,
  JourneyPackageRequest,
  JourneyBootstrapRequest,
  JourneyBootstrapResponse,
  JourneyArc,
  JourneyThemeKey
} from "./types";
import { normalizePackageFromObject } from "./validate";
import { estimateCostUSD } from "./cost";
import type { ProviderGenerationResult } from "./providers/openai";

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

function targetLanguage(
  request: JourneyBootstrapRequest
): { code: "en" | "es" | "pt" | "de" | "ja" | "ko"; label: string; localeIdentifier: string } {
  const languageCode = (request.languageCode ?? "").trim().toLowerCase();
  const localeIdentifier = (request.localeIdentifier ?? "").trim() || "en-US";
  if (languageCode.startsWith("es") || localeIdentifier.toLowerCase().startsWith("es")) {
    return { code: "es", label: "Spanish", localeIdentifier };
  }
  if (languageCode.startsWith("pt") || localeIdentifier.toLowerCase().startsWith("pt")) {
    return { code: "pt", label: "Portuguese (Brazil)", localeIdentifier };
  }
  if (languageCode.startsWith("de") || localeIdentifier.toLowerCase().startsWith("de")) {
    return { code: "de", label: "German", localeIdentifier };
  }
  if (languageCode.startsWith("ja") || localeIdentifier.toLowerCase().startsWith("ja")) {
    return { code: "ja", label: "Japanese", localeIdentifier };
  }
  if (languageCode.startsWith("ko") || localeIdentifier.toLowerCase().startsWith("ko")) {
    return { code: "ko", label: "Korean", localeIdentifier };
  }
  return { code: "en", label: "English", localeIdentifier };
}

function cleanText(value: unknown, maxLength: number): string {
  if (typeof value !== "string") return "";
  const trimmed = value.trim().replace(/\s+/g, " ");
  if (trimmed.length <= maxLength) return trimmed;

  const hard = trimmed.slice(0, maxLength);
  const sentenceBoundary = Math.max(
    hard.lastIndexOf("."),
    hard.lastIndexOf("!"),
    hard.lastIndexOf("?")
  );
  if (sentenceBoundary >= Math.floor(maxLength * 0.55)) {
    return hard.slice(0, sentenceBoundary + 1).trim();
  }

  const wordBoundary = hard.lastIndexOf(" ");
  if (wordBoundary >= Math.floor(maxLength * 0.55)) {
    return hard.slice(0, wordBoundary).trim();
  }

  // Preserve full model output if we cannot trim naturally.
  return trimmed;
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
  const goalIntentText = request.goalIntentText ?? "";
  const text = `${request.prayerIntentText} ${goalIntentText}`.toLowerCase();
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

function inferGrowthFocus(request: JourneyBootstrapRequest, themeKey: JourneyThemeKey): string {
  const rawGoal = cleanText(request.goalIntentText ?? "", 80);
  if (rawGoal.length >= 4) {
    return rawGoal;
  }

  const prayerFocus = cleanText(request.prayerIntentText, 80);
  if (prayerFocus.length >= 4) {
    return prayerFocus;
  }

  switch (themeKey) {
    case "peace":
      return "peace";
    case "resilience":
      return "resilience";
    case "patience":
      return "patience";
    case "faith":
      return "faith";
    case "joy":
      return "joy";
    case "wisdom":
      return "wisdom";
    case "healing":
      return "healing";
    case "discipline":
      return "discipline";
    case "community":
      return "community";
    default:
      return "consistency";
  }
}

function fallbackJourneyArc(request: JourneyBootstrapRequest, themeKey: JourneyThemeKey, growthFocus: string): JourneyArc {
  const purpose = cleanText(request.prayerIntentText, 140) || growthFocus || "grow in faithful action";
  const stageByTheme: Record<JourneyThemeKey, string> = {
    basic: "beginning with one faithful response",
    faith: "learning to trust God in one concrete area",
    patience: "slowing down before reacting",
    peace: "practicing peace in daily pressure",
    resilience: "building endurance through small faithful steps",
    community: "turning love into visible action",
    discipline: "forming consistency through one next step",
    healing: "moving gently toward wholeness",
    joy: "noticing and practicing gratitude",
    wisdom: "choosing the next wise step"
  };

  return {
    purpose,
    currentStage: stageByTheme[themeKey] ?? stageByTheme.basic,
    nextMovement: `Move from prayer about ${growthFocus || "this need"} into one concrete act today.`,
    tone: "grounded, sincere, practical, hopeful",
    practicalActionDirection: "Prefer specific real-life actions when the user's context supports them.",
    lastFollowThroughInterpretation: ""
  };
}

function fallbackBootstrap(request: JourneyBootstrapRequest): JourneyBootstrapResponse {
  const language = targetLanguage(request);
  const themeKey = fallbackTheme(request);
  const growthFocus = inferGrowthFocus(request, themeKey);
  const titleSeed = cleanText(request.prayerIntentText, 48) || cleanText(growthFocus, 48) || "First Journey";
  const journeyTitle = titleSeed.length < 4 ? "First Journey" : titleSeed;
  const journeyCategory = cleanText(request.prayerIntentText, 32) || "General";
  const pkg = fallbackPackage({
    profile: {
      prayerFocus: request.prayerIntentText,
      growthGoal: growthFocus,
      reminderWindow: request.reminderWindow
    },
    journey: {
      id: "bootstrap",
      title: journeyTitle,
      category: journeyCategory,
      themeKey
    },
    languageCode: request.languageCode,
    localeIdentifier: request.localeIdentifier
  });

  return {
    journeyTitle,
    journeyCategory,
    themeKey,
    growthFocus,
    journeyArc: fallbackJourneyArc(request, themeKey, growthFocus),
    initialMemory: {
      summary:
        language.code === "es"
          ? `${journeyTitle}: ${journeyCategory}.`
          : language.code === "pt"
            ? `${journeyTitle}: ${journeyCategory}.`
          : `${journeyTitle}: ${journeyCategory}.`,
      winsSummary:
        language.code === "es"
          ? "Aún no hay tends completados."
          : language.code === "pt"
            ? "Ainda não há tends concluídos."
            : language.code === "de"
              ? "Es gibt noch keine abgeschlossenen Tends."
            : language.code === "ja"
              ? "まだ完了したTendはありません。"
            : language.code === "ko"
              ? "아직 완료한 Tend가 없습니다."
            : "No completed tends yet.",
      blockersSummary:
        language.code === "es"
          ? "Aún no se detecta un patrón de bloqueo."
          : language.code === "pt"
            ? "Ainda não foi identificado um padrão de bloqueio."
            : language.code === "de"
              ? "Es wurde noch kein klares Blocker-Muster erkannt."
            : language.code === "ja"
              ? "まだ明確なつまずきの傾向は見つかっていません。"
            : language.code === "ko"
              ? "아직 방해 요인이 뚜렷하게 보이지 않습니다."
          : "No blocker pattern identified yet.",
      preferredTone: "grounded-encouraging"
    },
    initialPackage: pkg
  };
}

function buildBootstrapPrompt(request: JourneyBootstrapRequest): { system: string; user: string } {
  const language = targetLanguage(request);
  const system = [
    "You are generating initial journey setup for a Christian prayer-and-action app.",
    "Return strict JSON only.",
    "Classify the journey into one themeKey from:",
    THEME_KEYS.join(", "),
    "Create concise, practical initial memory and a daily package.",
    "Create a flexible journeyArc that gives the journey an ongoing story and practical direction without locking a fixed day-by-day plan.",
    "Do not include inflammatory denominational commentary, sectarian attacks, or arguments about which Christian tradition is superior.",
    "Keep religious language respectful, invitational, and non-coercive. Do not shame, threaten, or pressure the user spiritually.",
    "reflectionThought should be a natural concise reflection statement or gentle directive, not a question.",
    "Do not force a fixed opening phrase for reflectionThought.",
    "Do not always begin reflectionThought with 'Take a moment to reflect on'.",
    "Do not use first-person pronouns (I/me/my/we/us/our) in reflectionThought.",
    "reflectionThought must be exactly 4-5 complete sentences.",
    "Keep reflectionThought concrete, practical, and tied to this journey's next movement.",
    "Scripture paraphrase should be near-quote style: close to the selected verse wording with only subtle wording changes for the devotional focus.",
    "Keep scriptureParaphrase to 1-2 sentences and faithful to the cited verse’s central meaning.",
    "Do not blend ideas from unrelated verses into one paraphrase.",
    "Prayer must be exactly 3-4 complete sentences and strict first-person voice (I/me/my/we/us/our).",
    "smallStepQuestion must be one simple question, usually under 14 words, asking what the user can do today.",
    "Suggested step chips must include at least one concrete practical action when context supports it, plus a lower-friction option and a prayer/spiritual option when appropriate.",
    "For relationship or marriage contexts, specific actions like buying flowers, writing a note, apologizing, asking a direct question, or planning a short check-in are allowed when context supports them.",
    "Avoid unsafe, manipulative, expensive, shaming, or conflict-escalating suggestions.",
    "Never refer to the user in third person (for example: 'the user', 'they', or by name).",
    "Use scripture paraphrase only. No translation labels. No copyright-protected direct verse quoting.",
    "Keep tone grounded, sincere, practical, and hopeful.",
    `Write all user-facing generated text in ${language.label} (${language.code}).`,
    "Do not include translation notes, bilingual output, or language labels."
  ].join(" ");

  const user = JSON.stringify(
    {
      outputSchema: {
        journeyTitle: "string",
        journeyCategory: "string",
        themeKey: "one of fixed theme keys",
        growthFocus: "short inferred growth direction string",
        journeyArc: {
          purpose: "string",
          currentStage: "string",
          nextMovement: "string",
          tone: "string",
          practicalActionDirection: "string",
          lastFollowThroughInterpretation: "string"
        },
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
  const parsedGrowthFocus = cleanText(source.growthFocus, 80);
  const growthFocus = parsedGrowthFocus || fallback.growthFocus;
  const arcSource =
    source.journeyArc && typeof source.journeyArc === "object"
      ? (source.journeyArc as Record<string, unknown>)
      : {};
  const fallbackArc = fallbackJourneyArc(request, themeKey, growthFocus);
  const journeyArc: JourneyArc = {
    purpose: cleanText(arcSource.purpose, 180) || fallbackArc.purpose,
    currentStage: cleanText(arcSource.currentStage, 140) || fallbackArc.currentStage,
    nextMovement: cleanText(arcSource.nextMovement, 180) || fallbackArc.nextMovement,
    tone: cleanText(arcSource.tone, 100) || fallbackArc.tone,
    practicalActionDirection: cleanText(arcSource.practicalActionDirection, 180) || fallbackArc.practicalActionDirection,
    lastFollowThroughInterpretation: cleanText(arcSource.lastFollowThroughInterpretation, 160) || ""
  };

  const normalizationContext: JourneyPackageRequest = {
    profile: {
      prayerFocus: request.prayerIntentText,
      growthGoal: growthFocus,
      reminderWindow: request.reminderWindow
    },
    journey: {
      id: "bootstrap",
      title: cleanText(source.journeyTitle, 60) || fallback.journeyTitle,
      category: cleanText(source.journeyCategory, 40) || fallback.journeyCategory,
      themeKey
    },
    journeyArc,
    recentJourneySignals: [request.prayerIntentText, request.goalIntentText ?? "", growthFocus].filter(
      (signal) => signal.trim().length > 0
    ),
    languageCode: request.languageCode,
    localeIdentifier: request.localeIdentifier
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
    growthFocus,
    journeyArc,
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
    call: () => Promise<ProviderGenerationResult>;
  }> = [];

  if (openAIKey) {
    const escalationModel = process.env.OPENAI_ESCALATION_MODEL?.trim() || "gpt-5.1";
    candidates.push({
      provider: "openai",
      model: escalationModel,
      escalated: true,
      call: () => generateWithOpenAIPrompt(system, user, escalationModel, openAIKey)
    });
  }

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

  for (const candidate of candidates) {
    try {
      const generated = await candidate.call();
      const parsed = parseBootstrap(generated.text, request);
      if (!parsed) continue;
      return {
        bootstrap: parsed,
        provider: candidate.provider,
        model: candidate.model,
        escalated: candidate.escalated,
        fallbackUsed: false,
        usage: generated.usage
          ? {
              ...generated.usage,
              estimatedCostUSD: estimateCostUSD(candidate.provider, candidate.model, generated.usage)
            }
          : undefined
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
    fallbackUsed: true,
    usage: {
      inputTokens: 0,
      outputTokens: 0,
      totalTokens: 0,
      estimatedCostUSD: 0
    }
  };
}
