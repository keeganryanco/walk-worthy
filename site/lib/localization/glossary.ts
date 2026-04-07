export type LocalizationDomain = "posthog_onboarding" | "revenuecat_paywall";
export type LocalizationLocale = "es" | "pt-br";

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
