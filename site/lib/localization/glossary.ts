export type LocalizationDomain = "posthog_onboarding" | "revenuecat_paywall";
export type LocalizationLocale = "es" | "pt-br" | "ja" | "ko";

type GlossaryRules = {
  preferredTerms: Array<{ source: string; target: string }>;
  discouragedReplacements?: Array<{ from: string; to: string }>;
  styleNotes?: string[];
};

const glossaryByDomain: Record<LocalizationDomain, Partial<Record<LocalizationLocale, GlossaryRules>>> = {
  posthog_onboarding: {
    es: {
      preferredTerms: [
        { source: "journey", target: "camino" },
        { source: "prayer", target: "oración" },
        { source: "small step", target: "paso pequeño" },
        { source: "grow", target: "crecer" }
      ],
      discouragedReplacements: [{ from: "devocional", to: "oración guiada" }],
      styleNotes: ["Prefer warm, invitational tone. Avoid rigidly formal or archaic church language."]
    },
    "pt-br": {
      preferredTerms: [
        { source: "journey", target: "jornada" },
        { source: "prayer", target: "oração" },
        { source: "small step", target: "pequeno passo" },
        { source: "grow", target: "crescer" }
      ],
      discouragedReplacements: [{ from: "devoção", to: "oração guiada" }],
      styleNotes: ["Prefer natural Brazilian Portuguese. Avoid overly formal or imported literal phrasing."]
    },
    ja: {
      preferredTerms: [
        { source: "journey", target: "歩み" },
        { source: "prayer", target: "祈り" },
        { source: "small step", target: "小さな一歩" },
        { source: "grow", target: "成長する" }
      ],
      discouragedReplacements: [{ from: "デボーション", to: "祈りの導き" }],
      styleNotes: ["Use natural modern Japanese. Keep tone warm, clear, and invitational."]
    },
    ko: {
      preferredTerms: [
        { source: "journey", target: "여정" },
        { source: "prayer", target: "기도" },
        { source: "small step", target: "작은 걸음" },
        { source: "grow", target: "자라다" }
      ],
      discouragedReplacements: [{ from: "디보션", to: "묵상 기도" }],
      styleNotes: ["Use natural modern Korean. Keep sentence flow concise and warm rather than overly formal."]
    }
  },
  revenuecat_paywall: {
    es: {
      preferredTerms: [
        { source: "free trial", target: "prueba gratis" },
        { source: "cancel anytime", target: "cancela cuando quieras" }
      ],
      styleNotes: ["Keep subscription copy concise and plain-language."]
    },
    "pt-br": {
      preferredTerms: [
        { source: "free trial", target: "teste grátis" },
        { source: "cancel anytime", target: "cancele quando quiser" }
      ],
      styleNotes: ["Keep billing language simple and explicit for app-store compliance."]
    },
    ja: {
      preferredTerms: [
        { source: "free trial", target: "無料体験" },
        { source: "cancel anytime", target: "いつでも解約" }
      ],
      styleNotes: ["Keep subscription billing copy concise, plain, and app-store compliant."]
    },
    ko: {
      preferredTerms: [
        { source: "free trial", target: "무료 체험" },
        { source: "cancel anytime", target: "언제든지 해지" }
      ],
      styleNotes: ["Keep subscription billing copy plain and compliant. Avoid ambiguous legal phrasing."]
    }
  }
};

export function glossaryPromptHints(
  domain: LocalizationDomain,
  locale: LocalizationLocale
): string[] {
  const rules = glossaryByDomain[domain]?.[locale];
  if (!rules) {
    return [];
  }

  const preferred = rules.preferredTerms.map(
    (entry) => `- Prefer "${entry.target}" for "${entry.source}" when context matches.`
  );
  const notes = (rules.styleNotes ?? []).map((note) => `- ${note}`);

  return [...preferred, ...notes];
}

export function applySoftGlossaryNormalization(
  domain: LocalizationDomain,
  locale: LocalizationLocale,
  translated: Record<string, string>
): Record<string, string> {
  const rules = glossaryByDomain[domain]?.[locale];
  if (!rules || !rules.discouragedReplacements?.length) {
    return translated;
  }

  const normalized: Record<string, string> = {};
  for (const [key, value] of Object.entries(translated)) {
    let current = value;
    for (const replacement of rules.discouragedReplacements) {
      const pattern = new RegExp(`\\b${escapeRegex(replacement.from)}\\b`, "gi");
      current = current.replace(pattern, replacement.to);
    }
    normalized[key] = current;
  }
  return normalized;
}

function escapeRegex(input: string): string {
  return input.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
