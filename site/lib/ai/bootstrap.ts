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
import { devotionalModel as configuredDevotionalModel, repairModel as configuredRepairModel } from "./modelRouting";
import { APPROVED_SCRIPTURE_REFERENCES } from "./scripture";
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
  const purpose = cleanText(request.prayerIntentText, 140) || growthFocus || "grow with God in this concern";
  const stageByTheme: Record<JourneyThemeKey, string> = {
    basic: "beginning with honest attention",
    faith: "learning to trust God in one honest area",
    patience: "slowing down before reacting",
    peace: "receiving peace in daily pressure",
    resilience: "building endurance with patience",
    community: "learning love in visible relationships",
    discipline: "forming consistency with wisdom",
    healing: "moving gently toward wholeness",
    joy: "receiving gratitude with honesty",
    wisdom: "seeking wise direction"
  };

  return {
    purpose,
    journeyPurpose: purpose,
    currentStage: stageByTheme[themeKey] ?? stageByTheme.basic,
    todayAim: `Receive Scripture about ${growthFocus || "this need"} with honesty and trust.`,
    nextMovement: `Continue exploring ${growthFocus || "this need"} with more clarity, humility, and care.`,
    tone: "grounded, sincere, practical, hopeful",
    practicalActionDirection: "Prefer specific real-life actions when the user's context supports them.",
    recentDayTitles: [],
    specificContextSignals: [growthFocus, request.prayerIntentText].filter(Boolean).slice(0, 4),
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

function buildBootstrapPrompt(request: JourneyBootstrapRequest, repairNotes?: string): { system: string; user: string } {
  const language = targetLanguage(request);
  const system = [
    "You are generating initial journey setup for Tend, a personal Christian devotional journey app.",
    "Return strict JSON only.",
    "Classify the journey into one themeKey from:",
    THEME_KEYS.join(", "),
    "Create concise initial memory and a daily package.",
    "Create a flexible journeyArc that gives the journey an ongoing story and practical direction without locking a fixed day-by-day plan.",
    "Generate internally in this order: user's concern, broad journey direction, first topic/angle/message, Scripture, reflection, dailyTitle, prayer, action question, suggested steps.",
    "Privately decide the one clear devotional point this package is communicating before writing any field.",
    "The title, Scripture choice, reflection, prayer, action question, and suggested steps should all flow from that same point without sounding formulaic.",
    "The dailyTitle must name the same point the reflection develops. After sentence 2, reflectionThought must deepen that same title and point instead of moving to a neighboring topic.",
    "Use plain, easy-to-follow language in reflectionThought. A thoughtful child should be able to follow the main point, while an adult should still feel respected.",
    "Do not try to sound literary, academic, or impressive. Prefer common words when they communicate the same idea.",
    "One rich word is fine when it matters; do not stack abstract words like sentiment, passivity, defensiveness, posture, implication, or attentiveness.",
    "Do not include inflammatory denominational commentary, sectarian attacks, or arguments about which Christian tradition is superior.",
    "Keep religious language respectful, invitational, and non-coercive. Do not shame, threaten, or pressure the user spiritually.",
    "reflectionThought is teaching and interpretation, not assignment.",
    "reflectionThought must read as one coherent thought with a beginning, middle, and end: anchor in Scripture, explain what Scripture means in simple terms, connect to the user's journey, then close with a plain, grounded sentence.",
    "Do not use meta-devotional framing such as 'Today's lesson', 'the lesson is', 'the takeaway', 'this devotional', 'this reflection', or 'in conclusion'.",
    "Do not tell the user to send, buy, schedule, text, call, write, ask, apologize, plan, do, take, clean, cook, bring, serve, finish, or start a practical action inside reflectionThought.",
    "Do not use first-person pronouns (I/me/my/we/us/our) in reflectionThought.",
    "reflectionThought must be exactly 4-5 complete sentences.",
    "Keep reflectionThought concrete, Scripture-led, and tied to this journey's concern.",
    "Choose Scripture before writing the reflection. The reflection's main point must clearly arise from what the selected Scripture says, not merely sit beside a broadly related verse.",
    "Use one scripture reference by default. Use 2-3 references only when the combined passages truly deepen the same point; if using multiple references, separate them with semicolons.",
    "scriptureReference must come only from this approved scripture library:",
    APPROVED_SCRIPTURE_REFERENCES.join(", "),
    "Scripture paraphrase should be near-quote style: close to the selected verse wording with only subtle wording changes for the devotional focus.",
    "Keep scriptureParaphrase to 1-3 concise sentences and faithful to the cited verse or verses.",
    "If using multiple references, paraphrase each passage in the same order without blending them into a fake single verse.",
    "Do not turn Scripture into application language. scriptureParaphrase, reflectionThought, and prayer must not use faithful step, concrete step, small step, next step, move from prayer into action, what can you do, guide my action, or as I act.",
    "For marriage/spouse journeys, prefer passages about sacrificial love, patient love, humility, service, tenderness, and honoring a spouse, such as Ephesians 5:25, Colossians 3:19, 1 Peter 3:7, John 15:12, 1 Corinthians 13:4-7, Mark 10:45, or Galatians 5:13.",
    "For a breakup, death, loss, or heartbreak prompt, treat grief/comfort honestly rather than forcing generic relationship advice.",
    "For an ordinary event such as a driver's test, exam, interview, or appointment, keep the concrete event visible while naming the deeper need for wisdom, peace, courage, or trust.",
    "Prayer must be exactly 3-4 complete sentences and strict first-person voice (I/me/my/we/us/our).",
    "Prayer must name concrete realities from the user's journey and avoid empty Christianese such as reflect your grace more and more, deeper reliance, divine care, higher purpose, align my heart, walk in your truth, or grow closer to you.",
    "dailyTitle must be short, concrete, and story-like.",
    "Reject generic daily titles like Growing in Faith, Trusting God More, Daily Peace, A Step Toward Love, or Today's Faithful Step.",
    "smallStepQuestion must be one simple question, usually under 14 words, asking what the user can do today. Practical action language belongs only in smallStepQuestion and suggestedSteps.",
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
          journeyPurpose: "string",
          currentStage: "string",
          todayAim: "string",
          nextMovement: "string",
          tone: "string",
          practicalActionDirection: "string",
          recentDayTitles: ["string"],
          lastFollowThroughInterpretation: "string",
          specificContextSignals: ["string"]
        },
        initialMemory: {
          summary: "string",
          winsSummary: "string",
          blockersSummary: "string",
          preferredTone: "string"
        },
        initialPackage: {
          centralConcern: "specific concern inferred from the user's request, not a generic category",
          biblicalTheme: "specific biblical theme connecting the concern to Scripture",
          devotionalPoint: "one clear point the reflection, prayer, and action layer should serve",
          scriptureFitReason: "why the chosen reference fits this exact concern",
          dailyTitle: "string",
          reflectionThought: "string",
          scriptureReference: "string",
          scriptureParaphrase: "string",
          prayer: "string",
          todayAim: "string",
          smallStepQuestion: "string",
          suggestedSteps: ["string", "string", "string"],
          completionSuggestion: {
            shouldPrompt: false,
            reason: "string",
            confidence: "number"
          },
          updatedJourneyArc: "same structure as journeyArc"
        }
      },
      repairNotes: repairNotes ?? null,
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
    journeyPurpose:
      cleanText(arcSource.journeyPurpose, 180) ||
      cleanText(arcSource.purpose, 180) ||
      fallbackArc.journeyPurpose ||
      fallbackArc.purpose,
    currentStage: cleanText(arcSource.currentStage, 140) || fallbackArc.currentStage,
    todayAim: cleanText(arcSource.todayAim, 140) || fallbackArc.todayAim,
    nextMovement: cleanText(arcSource.nextMovement, 180) || fallbackArc.nextMovement,
    tone: cleanText(arcSource.tone, 100) || fallbackArc.tone,
    practicalActionDirection: cleanText(arcSource.practicalActionDirection, 180) || fallbackArc.practicalActionDirection,
    recentDayTitles: Array.isArray(arcSource.recentDayTitles)
      ? arcSource.recentDayTitles.map((item) => cleanText(item, 80)).filter(Boolean).slice(0, 8)
      : fallbackArc.recentDayTitles,
    specificContextSignals: Array.isArray(arcSource.specificContextSignals)
      ? arcSource.specificContextSignals.map((item) => cleanText(item, 80)).filter(Boolean).slice(0, 8)
      : fallbackArc.specificContextSignals,
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
  const packageWithArc = packageSource ? { ...packageSource, updatedJourneyArc: packageSource.updatedJourneyArc ?? journeyArc } : null;
  const normalizedPackage = packageWithArc ? normalizePackageFromObject(packageWithArc, normalizationContext) : null;

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
  const openAIKey = process.env.OPENAI_API_KEY?.trim();
  const geminiKey = process.env.GEMINI_API_KEY?.trim();
  const devotionalModel = configuredDevotionalModel();
  const repairModel = configuredRepairModel();

  const candidates: Array<{
    provider: "openai" | "gemini";
    model: string;
    escalated: boolean;
    call: () => Promise<ProviderGenerationResult>;
  }> = [];
  const diagnostics: string[] = [];

  if (openAIKey) {
    candidates.push({
      provider: "openai",
      model: devotionalModel,
      escalated: false,
      call: () => {
        const { system, user } = buildBootstrapPrompt(request);
        return generateWithOpenAIPrompt(system, user, devotionalModel, openAIKey);
      }
    });
  } else {
    diagnostics.push("missing_OPENAI_API_KEY");
  }

  if (openAIKey) {
    candidates.push({
      provider: "openai",
      model: repairModel,
      escalated: true,
      call: () => {
        const { system, user } = buildBootstrapPrompt(
          request,
          "Previous bootstrap package failed validation. Repair generic title, missing arc fields, reflection action commands, vague Christianese, sentence counts, scripture fidelity, and action relevance."
        );
        return generateWithOpenAIPrompt(system, user, repairModel, openAIKey);
      }
    });
  }

  if (geminiKey) {
    const primaryModel = process.env.GEMINI_PRIMARY_MODEL?.trim() || "gemini-2.5-flash";
    candidates.push({
      provider: "gemini",
      model: primaryModel,
      escalated: false,
      call: () => {
        const { system, user } = buildBootstrapPrompt(request);
        return generateWithGeminiPrompt(system, user, primaryModel, geminiKey);
      }
    });
  } else {
    diagnostics.push("missing_GEMINI_API_KEY");
  }

  for (const candidate of candidates) {
    try {
      const generated = await candidate.call();
      const parsed = parseBootstrap(generated.text, request);
      if (!parsed) {
        diagnostics.push(`${candidate.provider}_${candidate.model}_parse_or_validation_failed`);
        continue;
      }
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
          : undefined,
        diagnostics
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : "unknown";
      diagnostics.push(`${candidate.provider}_${candidate.model}_exception:${message}`);
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
    },
    diagnostics
  };
}
