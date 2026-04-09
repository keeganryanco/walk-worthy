import crypto from "node:crypto";
import { generateWithGeminiPrompt } from "../ai/providers/gemini";
import { generateWithOpenAIPrompt } from "../ai/providers/openai";
import { applySoftGlossaryNormalization, glossaryPromptHints } from "./glossary";

export type LocalizationDomain = "posthog_onboarding" | "revenuecat_paywall";
export type LocalizationProvider = "openai" | "gemini" | "template";

export interface LocalizeStringsInput {
  telemetry?: {
    distinctID?: string;
    appVersion?: string;
    buildNumber?: string;
    platform?: string;
  };
  domain: LocalizationDomain;
  targetLocale: string;
  strings: Record<string, string>;
}

export interface LocalizeStringsOutput {
  translated: Record<string, string>;
  meta: {
    provider: LocalizationProvider;
    model: string;
    cached: boolean;
    fallbackUsed: boolean;
  };
}

type CacheEntry = {
  translated: Record<string, string>;
  provider: LocalizationProvider;
  model: string;
  fallbackUsed: boolean;
  expiresAt: number;
};

type CandidateResult = {
  translated: Record<string, string>;
  provider: Exclude<LocalizationProvider, "template">;
  model: string;
};

type NormalizedTargetLocale = "en" | "es" | "pt-br" | "ja" | "ko";

const cache = new Map<string, CacheEntry>();

const PLACEHOLDER_PATTERNS = [
  /{{\s*[\w.-]+\s*}}/g,
  /%(?:\d+\$)?(?:@|d|i|u|f|g|e|x|X|o|c|s)/g
];

export async function localizeStrings(input: LocalizeStringsInput): Promise<LocalizeStringsOutput> {
  const normalizedTargetLocale = normalizeTargetLocale(input.targetLocale);
  const sourceStrings = sanitizeStrings(input.strings);

  if (Object.keys(sourceStrings).length === 0) {
    return {
      translated: {},
      meta: {
        provider: "template",
        model: "passthrough-empty",
        cached: false,
        fallbackUsed: false
      }
    };
  }

  if (normalizedTargetLocale === "en") {
    return {
      translated: sourceStrings,
      meta: {
        provider: "template",
        model: "passthrough-en",
        cached: false,
        fallbackUsed: false
      }
    };
  }

  const cacheKey = buildCacheKey(input.domain, normalizedTargetLocale, sourceStrings);
  const now = Date.now();
  const cached = cache.get(cacheKey);
  if (cached && cached.expiresAt > now) {
    return {
      translated: cached.translated,
      meta: {
        provider: cached.provider,
        model: cached.model,
        cached: true,
        fallbackUsed: cached.fallbackUsed
      }
    };
  }

  const candidates: Array<() => Promise<CandidateResult | null>> = [
    () => translateWithOpenAI(input.domain, normalizedTargetLocale, sourceStrings),
    () => translateWithGemini(input.domain, normalizedTargetLocale, sourceStrings)
  ];

  for (const candidate of candidates) {
    try {
      const result = await candidate();
      if (!result) {
        continue;
      }

      const sanitized = sanitizeTranslatedMap(sourceStrings, result.translated);
      const glossaryNormalized = applySoftGlossaryNormalization(
        input.domain,
        normalizedTargetLocale,
        sanitized.translated
      );
      const resolved: LocalizeStringsOutput = {
        translated: glossaryNormalized,
        meta: {
          provider: result.provider,
          model: result.model,
          cached: false,
          fallbackUsed: sanitized.fallbackUsed
        }
      };

      writeCache(cacheKey, resolved);
      return resolved;
    } catch {
      continue;
    }
  }

  const fallback: LocalizeStringsOutput = {
    translated: sourceStrings,
    meta: {
      provider: "template",
      model: "fallback-source",
      cached: false,
      fallbackUsed: true
    }
  };
  writeCache(cacheKey, fallback);
  return fallback;
}

function writeCache(key: string, output: LocalizeStringsOutput): void {
  cache.set(key, {
    translated: output.translated,
    provider: output.meta.provider,
    model: output.meta.model,
    fallbackUsed: output.meta.fallbackUsed,
    expiresAt: Date.now() + cacheTTLms()
  });
}

function cacheTTLms(): number {
  const defaultSeconds = 604800;
  const raw = process.env.LOCALIZATION_CACHE_TTL_SECONDS?.trim();
  const parsed = raw ? Number(raw) : defaultSeconds;

  if (!Number.isFinite(parsed) || parsed <= 0) {
    return defaultSeconds * 1000;
  }

  return Math.floor(parsed) * 1000;
}

function sanitizeStrings(input: Record<string, string>): Record<string, string> {
  const output: Record<string, string> = {};
  for (const [key, value] of Object.entries(input)) {
    const normalizedKey = key.trim();
    if (!normalizedKey) {
      continue;
    }
    output[normalizedKey] = typeof value === "string" ? value : String(value);
  }
  return output;
}

function normalizeTargetLocale(targetLocale: string): NormalizedTargetLocale {
  const normalized = targetLocale.trim().toLowerCase();
  if (normalized.startsWith("es")) {
    return "es";
  }
  if (normalized.startsWith("pt")) {
    return "pt-br";
  }
  if (normalized.startsWith("ja")) {
    return "ja";
  }
  if (normalized.startsWith("ko")) {
    return "ko";
  }
  return "en";
}

function buildCacheKey(
  domain: LocalizationDomain,
  targetLocale: string,
  strings: Record<string, string>
): string {
  const payload = `${domain}|${targetLocale}|${stableStringify(strings)}`;
  return crypto.createHash("sha256").update(payload).digest("hex");
}

function stableStringify(value: Record<string, string>): string {
  const sortedEntries = Object.keys(value)
    .sort((left, right) => left.localeCompare(right))
    .map((key) => [key, value[key]] as const);

  return JSON.stringify(Object.fromEntries(sortedEntries));
}

async function translateWithOpenAI(
  domain: LocalizationDomain,
  targetLocale: NormalizedTargetLocale,
  strings: Record<string, string>
): Promise<CandidateResult | null> {
  const apiKey = process.env.OPENAI_API_KEY?.trim();
  if (!apiKey) {
    return null;
  }

  const model =
    process.env.OPENAI_TRANSLATION_MODEL?.trim() ||
    process.env.OPENAI_PRIMARY_MODEL?.trim() ||
    "gpt-5-mini";

  const prompt = buildTranslationPrompt(domain, targetLocale, strings);
  const generated = await generateWithOpenAIPrompt(prompt.system, prompt.user, model, apiKey);
  const parsed = parseGeneratedDictionary(generated.text);

  if (!parsed) {
    return null;
  }

  return {
    translated: parsed,
    provider: "openai",
    model
  };
}

async function translateWithGemini(
  domain: LocalizationDomain,
  targetLocale: NormalizedTargetLocale,
  strings: Record<string, string>
): Promise<CandidateResult | null> {
  const apiKey = process.env.GEMINI_API_KEY?.trim();
  if (!apiKey) {
    return null;
  }

  const model =
    process.env.GEMINI_TRANSLATION_MODEL?.trim() ||
    process.env.GEMINI_PRIMARY_MODEL?.trim() ||
    "gemini-2.5-flash";

  const prompt = buildTranslationPrompt(domain, targetLocale, strings);
  const generated = await generateWithGeminiPrompt(prompt.system, prompt.user, model, apiKey);
  const parsed = parseGeneratedDictionary(generated.text);

  if (!parsed) {
    return null;
  }

  return {
    translated: parsed,
    provider: "gemini",
    model
  };
}

function buildTranslationPrompt(
  domain: LocalizationDomain,
  targetLocale: NormalizedTargetLocale,
  strings: Record<string, string>
): { system: string; user: string } {
  const localeName =
    targetLocale === "es"
      ? "Spanish"
      : targetLocale === "pt-br"
        ? "Portuguese (Brazil)"
        : targetLocale === "ja"
          ? "Japanese"
        : targetLocale === "ko"
          ? "Korean"
        : "English";
  const glossaryHints =
    targetLocale === "en"
      ? []
      : glossaryPromptHints(domain, targetLocale);

  const system = [
    "You are a high-precision product copy localizer.",
    `Domain: ${domain}.`,
    `Translate source strings to ${localeName}.`,
    "Return ONLY a JSON object.",
    "Rules:",
    "1) Keep exactly the same keys.",
    "2) Preserve placeholders exactly: mustache tokens ({{name}}) and printf tokens (%@, %d, %1$@, etc.).",
    "3) Do not add commentary or extra keys.",
    "4) Keep concise app-UI tone.",
    ...(glossaryHints.length > 0
      ? [
          "5) Soft glossary guidance (follow when contextually appropriate):",
          ...glossaryHints.map((hint) => `   - ${hint.replace(/^- /, "")}`)
        ]
      : [])
  ].join("\n");

  const user = JSON.stringify(
    {
      targetLocale,
      strings
    },
    null,
    2
  );

  return { system, user };
}

function parseGeneratedDictionary(text: string): Record<string, string> | null {
  const cleaned = unwrapCodeFence(text.trim());
  const candidates = [cleaned, extractFirstJSONObject(cleaned)].filter(
    (candidate): candidate is string => Boolean(candidate)
  );

  for (const candidate of candidates) {
    try {
      const parsed = JSON.parse(candidate) as unknown;
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
        continue;
      }

      const output: Record<string, string> = {};
      for (const [key, value] of Object.entries(parsed as Record<string, unknown>)) {
        if (typeof value === "string") {
          output[key] = value;
        }
      }

      return output;
    } catch {
      continue;
    }
  }

  return null;
}

function unwrapCodeFence(text: string): string {
  if (!text.startsWith("```")) {
    return text;
  }

  return text
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/, "")
    .trim();
}

function extractFirstJSONObject(text: string): string | null {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");

  if (start < 0 || end <= start) {
    return null;
  }

  return text.slice(start, end + 1);
}

function sanitizeTranslatedMap(
  source: Record<string, string>,
  translated: Record<string, string>
): { translated: Record<string, string>; fallbackUsed: boolean } {
  const resolved: Record<string, string> = {};
  let fallbackUsed = false;

  for (const [key, sourceValue] of Object.entries(source)) {
    const translatedValue = translated[key];
    const isValid =
      typeof translatedValue === "string" &&
      translatedValue.trim().length > 0 &&
      placeholdersMatch(sourceValue, translatedValue);

    if (!isValid) {
      resolved[key] = sourceValue;
      fallbackUsed = true;
      continue;
    }

    resolved[key] = translatedValue;
  }

  return { translated: resolved, fallbackUsed };
}

function placeholdersMatch(source: string, translated: string): boolean {
  const sourceTokens = extractPlaceholders(source);
  const translatedTokens = extractPlaceholders(translated);

  if (sourceTokens.length !== translatedTokens.length) {
    return false;
  }

  for (let index = 0; index < sourceTokens.length; index += 1) {
    if (sourceTokens[index] !== translatedTokens[index]) {
      return false;
    }
  }

  return true;
}

function extractPlaceholders(input: string): string[] {
  const placeholders: string[] = [];

  for (const pattern of PLACEHOLDER_PATTERNS) {
    const matches = input.match(pattern);
    if (matches) {
      placeholders.push(...matches);
    }
  }

  return placeholders.sort((left, right) => left.localeCompare(right));
}
