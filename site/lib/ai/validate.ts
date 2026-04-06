import { DailyJourneyPackage } from "./types";
import { JourneyPackageRequest } from "./types";
import { deterministicReference, normalizeReference } from "./scripture";

const CHIP_MIN_WORDS = 2;
const CHIP_MAX_WORDS = 7;
const CHIP_MAX_LENGTH = 80;
const CHIP_LIMIT = 4;
const CHIP_FALLBACK_COUNT = 3;

type SupportedLanguageCode = "en" | "es";

const DANGLING_ENDINGS_EN = new Set([
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

const DANGLING_ENDINGS_ES = new Set([
  "a",
  "al",
  "con",
  "de",
  "del",
  "el",
  "en",
  "la",
  "las",
  "los",
  "o",
  "para",
  "por",
  "que",
  "un",
  "una",
  "y"
]);

const LEADING_FRAGMENT_WORDS_EN = new Set([
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

const LEADING_FRAGMENT_WORDS_ES = new Set([
  "con",
  "cuando",
  "mientras",
  "o",
  "para",
  "porque",
  "que",
  "si",
  "y"
]);

const themeChipBankEn: Record<string, string[]> = {
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

const themeChipBankEs: Record<string, string[]> = {
  basic: ["Ora por una tarea", "Da un paso fiel", "Termina una tarea pendiente"],
  faith: ["Ora con plena confianza", "Escribe una verdad de fe", "Entrega un área de control"],
  patience: ["Espera antes de reaccionar", "Elige un paso tranquilo", "Avanza una tarea atrasada"],
  peace: ["Respira profundo cinco veces", "Ora por una preocupación", "Silencia una distracción"],
  resilience: ["Haz algo difícil hoy", "Reformula un tropiezo", "Pide fuerzas para hoy"],
  community: ["Envía un mensaje de ánimo", "Ora por un amigo", "Agenda un seguimiento"],
  discipline: ["Define un bloque de enfoque", "Quita una distracción", "Empieza ahora mismo"],
  healing: ["Nombra una emoción real", "Da un paso de cuidado", "Pide apoyo hoy"],
  joy: ["Escribe tres gratitudes", "Celebra un pequeño avance", "Comparte una alabanza"],
  wisdom: ["Pausa y pide sabiduría", "Define un paso sabio", "Busca consejo confiable"]
};

const contextualKeywordChipsEn: Array<{ pattern: RegExp; chips: string[] }> = [
  { pattern: /(anx|worr|fear|stress|panic|calm|rest|peace)/i, chips: ["Pray through this worry", "Take five calm breaths"] },
  { pattern: /(focus|disciplin|habit|procrastin|delay|consisten)/i, chips: ["Start one focused block", "Finish one delayed task"] },
  { pattern: /(family|marriage|friend|relationship|team|community)/i, chips: ["Send one honest message", "Pray for this relationship"] },
  { pattern: /(money|financial|budget|debt|career|business|work)/i, chips: ["Review one key number", "Take one work action"] },
  { pattern: /(health|heal|grief|pain|recover|tired)/i, chips: ["Take one healing step", "Rest and pray ten minutes"] }
];

const contextualKeywordChipsEs: Array<{ pattern: RegExp; chips: string[] }> = [
  { pattern: /(ansied|preocup|miedo|estr[eé]s|calma|descanso|paz)/i, chips: ["Ora por esta preocupación", "Respira y vuelve a orar"] },
  { pattern: /(enfoque|disciplina|h[aá]bito|procrastin|constancia|demora)/i, chips: ["Haz un bloque de enfoque", "Termina una tarea pendiente"] },
  { pattern: /(familia|matrimonio|amig|relaci[oó]n|comunidad)/i, chips: ["Envía un mensaje sincero", "Ora por esta relación"] },
  { pattern: /(dinero|financ|presupuesto|deuda|carrera|trabajo|negocio)/i, chips: ["Revisa un número clave", "Da un paso laboral hoy"] },
  { pattern: /(salud|sanidad|duelo|dolor|recuper)/i, chips: ["Da un paso de sanidad", "Descansa y ora diez minutos"] }
];

const genericFallbackChipsEn = ["Pray and choose one step", "Take one faithful action", "Write today's next step"];
const genericFallbackChipsEs = ["Ora y elige un paso", "Da una acción fiel", "Escribe tu próximo paso"];
const FIRST_PERSON_PRAYER_REGEX_EN = /\b(i|i'm|i’ve|i've|i’d|i'll|i’ll|me|my|mine|myself|we|we're|we’ve|we've|we’d|we'll|we’ll|us|our|ours|ourselves)\b/i;
const FIRST_PERSON_PRAYER_REGEX_ES = /\b(yo|mi|m[ií]o|m[ií]a|m[ií]os|m[ií]as|m[ií]|me|conmigo|nosotros|nosotras|nuestro|nuestra|nuestros|nuestras|nos)\b/i;
const FIRST_PERSON_REFLECTION_REGEX = /\b(i|i'm|i’ve|i've|i’d|i'll|i’ll|me|my|mine|myself|we|we're|we’ve|we've|we’d|we'll|we’ll|us|our|ours|ourselves)\b/i;
const PROSE_END_REGEX = /[.!?]["')\]]?$/;
const DISALLOWED_THIRD_PERSON_PRAYER_PHRASES_EN = [
  "the user",
  "this user",
  "for the user",
  "their journey",
  "his journey",
  "her journey"
];
const DISALLOWED_THIRD_PERSON_PRAYER_PHRASES_ES = [
  "el usuario",
  "la usuaria",
  "este usuario",
  "esta usuaria",
  "su camino",
  "su jornada"
];
const QUESTION_START_REGEX_EN = /^(how|what|why|when|where|who|can|could|should|would|do|does|did|is|are|am|will|have|has|had)\b/i;
const QUESTION_START_REGEX_ES = /^(c[oó]mo|qu[eé]|por qu[eé]|cu[aá]ndo|d[oó]nde|qui[eé]n|puedo|puedes|debo|deber[ií]a|es|son|est[aá]|est[aá]n|hay)\b/i;
type FollowThroughStatus = "yes" | "partial" | "no" | "unanswered";

function languageCode(input?: JourneyPackageRequest): SupportedLanguageCode {
  const raw = (input?.languageCode ?? input?.localeIdentifier ?? "").toLowerCase();
  return raw.startsWith("es") ? "es" : "en";
}

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
  const trimmed = value.trim().replace(/\s+/g, " ");
  if (trimmed.length <= maxLength) {
    return trimmed;
  }

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

  // Preserve full model output if we cannot trim at a natural boundary.
  // This prevents mid-sentence clipping in the app UI.
  return trimmed;
}

function normalizeProseEnding(value: string): string {
  const trimmed = value.trim();
  if (!trimmed) return "";
  if (PROSE_END_REGEX.test(trimmed)) return trimmed;

  const sentenceBoundary = Math.max(
    trimmed.lastIndexOf("."),
    trimmed.lastIndexOf("!"),
    trimmed.lastIndexOf("?")
  );
  if (sentenceBoundary >= Math.floor(trimmed.length * 0.45)) {
    return trimmed.slice(0, sentenceBoundary + 1).trim();
  }

  const wordBoundary = trimmed.lastIndexOf(" ");
  if (wordBoundary >= Math.floor(trimmed.length * 0.7)) {
    const candidate = trimmed.slice(0, wordBoundary).trim();
    if (candidate) {
      return `${candidate}.`;
    }
  }

  return trimmed;
}

function normalizeChip(value: unknown, language: SupportedLanguageCode): string {
  const cleaned = cleanText(value, CHIP_MAX_LENGTH).replace(/[^\p{L}\p{N}\s'-]/gu, " ");
  if (!cleaned) return "";

  const compact = cleaned.replace(/\s+/g, " ").trim();
  if (!compact) return "";

  const words = compact.split(" ");
  if (words.length < CHIP_MIN_WORDS || words.length > CHIP_MAX_WORDS) {
    return "";
  }

  const leadingWords = language === "es" ? LEADING_FRAGMENT_WORDS_ES : LEADING_FRAGMENT_WORDS_EN;
  const danglingEndings = language === "es" ? DANGLING_ENDINGS_ES : DANGLING_ENDINGS_EN;
  const firstWord = words[0]?.toLowerCase() ?? "";
  const lastWord = words[words.length - 1]?.toLowerCase() ?? "";
  if (leadingWords.has(firstWord) || danglingEndings.has(lastWord)) {
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
  const language = languageCode(input);
  const status = followThroughStatus(input);
  if (status === "partial" || status === "no") {
    return language === "es"
      ? ["Haz un paso de dos minutos", "Elige una acción más fácil", "Ora y empieza pequeño"]
      : ["Take a two minute step", "Choose one easier action", "Pray then start small"];
  }

  const themeKey = input?.journey.themeKey ?? "basic";
  const baseBank = language === "es" ? themeChipBankEs : themeChipBankEn;
  const keywordSets = language === "es" ? contextualKeywordChipsEs : contextualKeywordChipsEn;
  const genericFallback = language === "es" ? genericFallbackChipsEs : genericFallbackChipsEn;
  const chips: string[] = [...(baseBank[themeKey] ?? baseBank.basic)];

  const signals = contextSignals(input);
  for (const keywordSet of keywordSets) {
    if (keywordSet.pattern.test(signals)) {
      chips.push(...keywordSet.chips);
    }
  }

  chips.push(...genericFallback);
  const normalized = dedupeChips(chips.map((chip) => normalizeChip(chip, language)).filter(Boolean));
  return normalized.slice(0, CHIP_FALLBACK_COUNT);
}

function normalizedChips(rawValues: unknown[], input?: JourneyPackageRequest): string[] {
  const language = languageCode(input);
  const genericFallback = language === "es" ? genericFallbackChipsEs : genericFallbackChipsEn;
  const generated = dedupeChips(rawValues.map((item) => normalizeChip(item, language)).filter(Boolean)).slice(0, CHIP_LIMIT);
  const contextual = contextualFallbackChips(input);

  const merged = dedupeChips([...generated, ...contextual]).slice(0, CHIP_LIMIT);
  if (merged.length >= CHIP_FALLBACK_COUNT) {
    return merged;
  }

  const toppedUp = dedupeChips([...merged, ...genericFallback.map((chip) => normalizeChip(chip, language)).filter(Boolean)]).slice(
    0,
    CHIP_LIMIT
  );
  if (toppedUp.length >= CHIP_FALLBACK_COUNT) {
    return toppedUp;
  }

  return (language === "es"
    ? ["Ora y elige un paso", "Da una acción fiel", "Escribe tu próximo paso"]
    : ["Pray and choose one step", "Take one faithful action", "Write today's next step"]
  ).slice(0, CHIP_LIMIT);
}

function normalizeFirstPersonPrayer(value: unknown, input?: JourneyPackageRequest): string {
  const trimmed = normalizeProseEnding(cleanText(value, 900));
  if (!trimmed) return "";

  const normalized = trimmed.toLowerCase().replace(/[’`]/g, "'");
  const language = languageCode(input);
  const disallowedPhrases =
    language === "es" ? DISALLOWED_THIRD_PERSON_PRAYER_PHRASES_ES : DISALLOWED_THIRD_PERSON_PRAYER_PHRASES_EN;
  if (disallowedPhrases.some((phrase) => normalized.includes(phrase))) {
    return "";
  }

  const firstPersonRegex = language === "es" ? FIRST_PERSON_PRAYER_REGEX_ES : FIRST_PERSON_PRAYER_REGEX_EN;
  return firstPersonRegex.test(normalized) ? trimmed : "";
}

function fallbackReflectionThought(input?: JourneyPackageRequest): string {
  const language = languageCode(input);
  const focus = cleanText(input?.profile.growthGoal, 140) || cleanText(input?.profile.prayerFocus, 140);
  if (focus) {
    return language === "es"
      ? `La fe puede guiar tu camino en ${focus.replace(/[.!?]+$/g, "")}.`
      : `Faith can guide your path in ${focus.replace(/[.!?]+$/g, "")}.`;
  }
  return language === "es"
    ? "Una acción fiel hoy puede formar un crecimiento duradero."
    : "Faithful action today can shape long-term growth.";
}

function normalizeReflectionThought(value: unknown, input?: JourneyPackageRequest): string {
  const raw = cleanText(value, 520);
  const fallback = fallbackReflectionThought(input);
  const language = languageCode(input);
  if (!raw) return fallback;

  const alreadyDirective = /^take a moment to reflect on\b/i.test(raw) || /^reflect on\b/i.test(raw);
  const questionStartRegex = language === "es" ? QUESTION_START_REGEX_ES : QUESTION_START_REGEX_EN;
  const originalLooksQuestion = questionStartRegex.test(raw) || raw.includes("?");
  const originalUsesFirstPerson = FIRST_PERSON_REFLECTION_REGEX.test(raw);

  let normalized = raw
    .replace(/\?/g, " ")
    .replace(/\bmy\b/gi, "your")
    .replace(/\bmine\b/gi, "yours")
    .replace(/\bme\b/gi, "you")
    .replace(/\bi\b/gi, "you")
    .replace(/\bour\b/gi, "your")
    .replace(/\bours\b/gi, "yours")
    .replace(/\bus\b/gi, "you")
    .replace(/\bwe\b/gi, "you")
    .replace(/\bwe're\b/gi, "you're")
    .replace(/\s+/g, " ")
    .trim();

  if (!originalLooksQuestion && !originalUsesFirstPerson && !alreadyDirective) {
    return `${normalized.replace(/[.!?]+$/g, "").trim()}.`;
  }

  if (language === "es") {
    normalized = normalized
      .replace(/^t[oó]mate un momento para reflexionar sobre\s+/i, "")
      .replace(/^reflexiona sobre\s+/i, "")
      .replace(/[.!?]+$/g, "")
      .trim();
  } else {
    normalized = normalized
      .replace(/^take a moment to reflect on\s+/i, "")
      .replace(/^reflect on\s+/i, "")
      .replace(/^(how|what|why|when|where|who)\s+(do|does|did|can|could|should|would|is|are|am|will|have|has|had)\s+/i, "")
      .replace(/^(do|does|did|can|could|should|would|is|are|am|will|have|has|had)\s+/i, "")
      .replace(/[.!?]+$/g, "")
      .trim();
  }

  if (!normalized) return fallback;
  return `${normalized.replace(/[.!?]+$/g, "").trim()}.`;
}

const referenceParaphraseFallbacks: Record<string, string> = {
  "Philippians 4:6-7":
    "Bring every worry and request to God with thanksgiving, and His peace will guard your heart and mind in Christ.",
  "Proverbs 16:3":
    "Commit your work to the Lord, and He will establish your plans.",
  "Matthew 6:33":
    "Seek God’s kingdom first, and trust Him to provide what you need.",
  "Galatians 6:9":
    "Do not grow weary in doing good, because in due time you will reap a harvest if you do not give up.",
  "1 Corinthians 15:58":
    "Stand firm and keep giving yourself fully to the Lord’s work, because your labor in Him is not in vain.",
  "Joshua 1:9":
    "Be strong and courageous, do not be afraid, for the Lord your God is with you wherever you go.",
  "2 Timothy 1:7":
    "God gives you a spirit of power, love, and self-control, not fear.",
  "Isaiah 26:3":
    "God keeps in perfect peace the one whose mind is steadfast and trusting in Him.",
  "Colossians 3:23":
    "Work wholeheartedly, as for the Lord and not for people.",
  "1 Corinthians 9:27":
    "Practice disciplined self-control so your life stays aligned with what you proclaim.",
  "Galatians 5:13":
    "Use your freedom to serve one another humbly in love.",
  "Mark 10:45":
    "The Son of Man came not to be served but to serve and to give His life for many."
};

const referenceAnchorRules: Record<string, string[]> = {
  "Philippians 4:6-7": ["pray", "request", "peace", "anxious", "thank"],
  "Proverbs 16:3": ["commit", "work", "lord", "plans", "establish"],
  "Matthew 6:33": ["seek", "kingdom", "righteous", "first", "provide"],
  "Galatians 6:9": ["weary", "good", "reap", "harvest", "give up"],
  "1 Corinthians 15:58": ["stand firm", "steadfast", "lord", "work", "not in vain"],
  "Joshua 1:9": ["strong", "courageous", "afraid", "with you", "wherever"],
  "2 Timothy 1:7": ["spirit", "power", "love", "self-control", "fear"],
  "Isaiah 26:3": ["perfect peace", "mind", "steadfast", "trust", "trusts"],
  "Colossians 3:23": ["work", "heartily", "lord", "not for", "people"],
  "1 Corinthians 9:27": ["discipline", "self-control", "body", "proclaim", "disqualified"],
  "Galatians 5:13": ["freedom", "serve", "one another", "love", "humble"],
  "Mark 10:45": ["serve", "served", "son of man", "ransom", "many"]
};

const referenceOffTargetSignals: Record<string, string[]> = {
  "Philippians 4:6-7": ["plans", "establish", "business", "provision", "career", "success"]
};

function enforceParaphraseFidelity(reference: string, paraphrase: string): string {
  const fallback = referenceParaphraseFallbacks[reference];
  const anchors = referenceAnchorRules[reference];
  if (!fallback || !anchors) {
    return paraphrase;
  }

  const lower = paraphrase.toLowerCase();
  const anchorMatches = anchors.reduce((count, anchor) => (lower.includes(anchor) ? count + 1 : count), 0);
  const offTargetMatches = (referenceOffTargetSignals[reference] ?? []).reduce(
    (count, signal) => (lower.includes(signal) ? count + 1 : count),
    0
  );

  if (anchorMatches < 2 || (anchorMatches === 0 && offTargetMatches >= 2)) {
    return fallback;
  }

  return paraphrase;
}

function collectUsedScriptureReferences(input?: JourneyPackageRequest): string[] {
  if (!input) {
    return [];
  }

  const fromHistory = (input.recentEntries ?? [])
    .map((entry) => normalizeReference(cleanText(entry.scriptureReference, 120)))
    .filter(Boolean);
  const fromPayload = (input.usedScriptureReferences ?? [])
    .map((value) => normalizeReference(cleanText(value, 120)))
    .filter(Boolean);

  return Array.from(new Set([...fromHistory, ...fromPayload]));
}

function nonRepeatingReference(candidate: string, input?: JourneyPackageRequest): string {
  const used = collectUsedScriptureReferences(input);
  if (used.length === 0 || !used.includes(candidate)) {
    return candidate;
  }

  const seed = `${input?.journey?.id ?? "journey"}-${input?.dateISO ?? "today"}`;
  return deterministicReference(seed, used);
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
  const language = languageCode(input);
  const defaultQuestion =
    status === "partial" || status === "no"
      ? language === "es"
        ? "¿Cuál es un paso pequeño que sí puedes terminar hoy?"
        : "What is one small step you can realistically finish today?"
      : language === "es"
        ? "¿Qué paso pequeño podrías dar hoy?"
        : "What small step could you take today?";

  const referenceCandidate = normalizeReference(cleanText(source.scriptureReference, 120));
  const uniqueReference = nonRepeatingReference(referenceCandidate, input);

  const normalized: DailyJourneyPackage = {
    reflectionThought: normalizeReflectionThought(source.reflectionThought, input),
    scriptureReference: uniqueReference,
    scriptureParaphrase: normalizeProseEnding(
      enforceParaphraseFidelity(
        uniqueReference,
        cleanText(source.scriptureParaphrase, 900)
      )
    ),
    prayer: normalizeFirstPersonPrayer(source.prayer, input),
    smallStepQuestion: cleanText(source.smallStepQuestion, 320) || defaultQuestion,
    suggestedSteps: suggested,
    completionSuggestion: {
      shouldPrompt: completionRaw.shouldPrompt === true,
      reason: cleanText(completionRaw.reason, 260),
      confidence
    }
  };

  if (!normalized.reflectionThought || !normalized.scriptureParaphrase || !normalized.prayer) {
    return null;
  }

  return normalized;
}
