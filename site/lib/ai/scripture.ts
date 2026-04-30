export type ScriptureTheme =
  | "anxiety"
  | "ambition"
  | "calling"
  | "community"
  | "discipline"
  | "faith"
  | "forgiveness"
  | "grief"
  | "healing"
  | "hope"
  | "humility"
  | "identity"
  | "joy"
  | "love"
  | "marriage"
  | "patience"
  | "peace"
  | "resilience"
  | "service"
  | "wisdom"
  | "work";

export interface ScriptureLibraryEntry {
  reference: string;
  paraphrase: string;
  anchors: string[];
  themes: ScriptureTheme[];
}

export const SCRIPTURE_LIBRARY = [
  {
    reference: "Philippians 4:6-7",
    paraphrase: "Bring every worry and request to God with thanksgiving, and His peace will guard your heart and mind in Christ.",
    anchors: ["worry", "request", "thanksgiving", "peace", "guard"],
    themes: ["anxiety", "peace", "faith"]
  },
  {
    reference: "Matthew 5:16",
    paraphrase: "Let your light shine before others, so they may see your good works and give glory to your Father in heaven.",
    anchors: ["light", "shine", "good works", "glory", "Father"],
    themes: ["calling", "ambition", "service", "work"]
  },
  {
    reference: "Ephesians 2:10",
    paraphrase: "We are God's workmanship, created in Christ Jesus for good works that God prepared for us to walk in.",
    anchors: ["workmanship", "created", "good works", "prepared", "walk"],
    themes: ["calling", "identity", "work", "ambition"]
  },
  {
    reference: "Colossians 3:17",
    paraphrase: "Whatever you do in word or deed, do it all in the name of the Lord Jesus, giving thanks to God.",
    anchors: ["word", "deed", "name", "Lord Jesus", "thanks"],
    themes: ["calling", "work", "ambition", "faith"]
  },
  {
    reference: "James 1:5",
    paraphrase: "If anyone lacks wisdom, they should ask God, who gives generously without finding fault.",
    anchors: ["wisdom", "ask", "God", "generously", "without finding fault"],
    themes: ["wisdom", "calling", "work", "anxiety"]
  },
  {
    reference: "Romans 12:10",
    paraphrase: "Be devoted to one another in love, and honor one another above yourselves.",
    anchors: ["devoted", "one another", "love", "honor", "above yourselves"],
    themes: ["love", "community", "marriage", "service"]
  },
  {
    reference: "Ephesians 5:25",
    paraphrase: "Husbands are called to love their wives as Christ loved the church and gave Himself for her.",
    anchors: ["husbands", "love", "wives", "Christ", "gave Himself"],
    themes: ["marriage", "love", "service"]
  },
  {
    reference: "John 15:12",
    paraphrase: "Jesus commands His disciples to love one another as He has loved them.",
    anchors: ["Jesus", "commands", "love one another", "loved", "disciples"],
    themes: ["love", "service", "marriage", "community"]
  },
  {
    reference: "1 Corinthians 13:4-7",
    paraphrase: "Love is patient and kind; it is not proud or self-seeking, and it bears, believes, hopes, and endures.",
    anchors: ["patient", "kind", "not proud", "not self-seeking", "endures"],
    themes: ["love", "marriage", "patience", "community"]
  },
  {
    reference: "Colossians 3:19",
    paraphrase: "Husbands are told to love their wives and not be harsh with them.",
    anchors: ["husbands", "love", "wives", "not harsh"],
    themes: ["marriage", "love", "patience"]
  },
  {
    reference: "1 Peter 3:7",
    paraphrase: "Husbands are told to live with their wives with understanding and to honor them.",
    anchors: ["husbands", "wives", "understanding", "honor"],
    themes: ["marriage", "love", "wisdom"]
  },
  {
    reference: "Mark 10:45",
    paraphrase: "The Son of Man came not to be served but to serve and to give His life for many.",
    anchors: ["Son of Man", "not to be served", "serve", "give His life", "many"],
    themes: ["service", "love", "marriage", "humility"]
  },
  {
    reference: "Galatians 5:13",
    paraphrase: "Use your freedom to serve one another humbly in love.",
    anchors: ["freedom", "serve", "one another", "humbly", "love"],
    themes: ["service", "love", "community", "marriage"]
  },
  {
    reference: "Matthew 22:37-39",
    paraphrase: "Jesus says to love the Lord your God with all your heart, soul, and mind, and to love your neighbor as yourself.",
    anchors: ["love", "Lord", "heart", "soul", "neighbor"],
    themes: ["love", "faith", "community"]
  },
  {
    reference: "Philippians 2:3-4",
    paraphrase: "Do nothing from selfish ambition, but in humility value others above yourselves and look to their interests.",
    anchors: ["selfish ambition", "humility", "value others", "above yourselves", "interests"],
    themes: ["service", "love", "marriage", "ambition"]
  },
  {
    reference: "1 John 3:18",
    paraphrase: "Do not love only with words or speech, but with action and truth.",
    anchors: ["love", "words", "speech", "action", "truth"],
    themes: ["love", "service", "marriage", "community"]
  },
  {
    reference: "Proverbs 3:5-6",
    paraphrase: "Trust in the Lord with all your heart, do not lean on your own understanding, and He will make your paths straight.",
    anchors: ["trust", "Lord", "heart", "understanding", "paths"],
    themes: ["faith", "wisdom", "calling", "anxiety"]
  },
  {
    reference: "Proverbs 16:3",
    paraphrase: "Commit your work to the Lord, and He will establish your plans.",
    anchors: ["commit", "work", "Lord", "establish", "plans"],
    themes: ["work", "calling", "ambition", "faith"]
  },
  {
    reference: "1 Corinthians 10:31",
    paraphrase: "Whether you eat or drink or whatever you do, do everything for the glory of God.",
    anchors: ["whatever", "do", "everything", "glory", "God"],
    themes: ["calling", "work", "ambition", "faith"]
  },
  {
    reference: "Galatians 1:10",
    paraphrase: "If seeking people's approval ruled the heart, it would not be the service of Christ.",
    anchors: ["approval", "people", "heart", "service", "Christ"],
    themes: ["ambition", "identity", "calling", "work"]
  },
  {
    reference: "Proverbs 21:5",
    paraphrase: "The plans of the diligent lead surely to abundance, but haste leads only to lack.",
    anchors: ["plans", "diligent", "lead", "abundance", "haste"],
    themes: ["work", "discipline", "wisdom", "ambition"]
  },
  {
    reference: "Matthew 6:33",
    paraphrase: "Seek God's kingdom first, and trust Him to provide what you need.",
    anchors: ["seek", "kingdom", "first", "provide", "need"],
    themes: ["faith", "calling", "peace", "work"]
  },
  {
    reference: "1 Peter 5:6-7",
    paraphrase: "Humble yourselves under God's mighty hand, casting all your anxieties on Him because He cares for you.",
    anchors: ["humble", "mighty hand", "anxieties", "cares", "God"],
    themes: ["anxiety", "peace", "faith", "humility"]
  },
  {
    reference: "Isaiah 26:3",
    paraphrase: "God keeps in perfect peace the one whose mind is steadfast because that person trusts in Him.",
    anchors: ["perfect peace", "mind", "steadfast", "trusts", "God"],
    themes: ["peace", "anxiety", "faith"]
  },
  {
    reference: "2 Timothy 1:7",
    paraphrase: "God gives a spirit not of fear, but of power, love, and self-control.",
    anchors: ["God", "fear", "power", "love", "self-control"],
    themes: ["anxiety", "discipline", "faith", "resilience"]
  },
  {
    reference: "John 14:27",
    paraphrase: "Jesus gives His peace, not as the world gives, and tells troubled hearts not to be afraid.",
    anchors: ["Jesus", "peace", "world", "troubled", "afraid"],
    themes: ["peace", "anxiety", "faith"]
  },
  {
    reference: "Matthew 6:34",
    paraphrase: "Do not be anxious about tomorrow, because tomorrow will have concerns of its own.",
    anchors: ["anxious", "tomorrow", "concerns", "own"],
    themes: ["anxiety", "peace", "faith"]
  },
  {
    reference: "Psalm 94:19",
    paraphrase: "When many cares fill the heart, God's comforts bring joy to the soul.",
    anchors: ["cares", "heart", "comforts", "joy", "soul"],
    themes: ["anxiety", "peace", "joy", "healing"]
  },
  {
    reference: "Psalm 34:18",
    paraphrase: "The Lord is near to the brokenhearted and saves those crushed in spirit.",
    anchors: ["Lord", "near", "brokenhearted", "saves", "crushed"],
    themes: ["grief", "healing", "peace"]
  },
  {
    reference: "Matthew 5:4",
    paraphrase: "Blessed are those who mourn, for they will be comforted.",
    anchors: ["blessed", "mourn", "comforted"],
    themes: ["grief", "healing", "peace"]
  },
  {
    reference: "2 Corinthians 1:3-4",
    paraphrase: "God is the Father of mercies and God of all comfort, who comforts us in our troubles.",
    anchors: ["Father", "mercies", "comfort", "troubles", "God"],
    themes: ["grief", "healing", "community"]
  },
  {
    reference: "Revelation 21:4",
    paraphrase: "God will wipe away every tear, and death, mourning, crying, and pain will be no more.",
    anchors: ["wipe away", "tear", "death", "mourning", "pain"],
    themes: ["grief", "healing", "hope"]
  },
  {
    reference: "Ephesians 4:32",
    paraphrase: "Be kind and tenderhearted to one another, forgiving as God in Christ forgave you.",
    anchors: ["kind", "tenderhearted", "forgiving", "God", "Christ"],
    themes: ["forgiveness", "love", "community", "marriage"]
  },
  {
    reference: "James 1:19-20",
    paraphrase: "Be quick to listen, slow to speak, and slow to anger, because anger does not produce God's righteousness.",
    anchors: ["listen", "speak", "anger", "righteousness", "God"],
    themes: ["wisdom", "forgiveness", "patience", "community"]
  },
  {
    reference: "Romans 12:18",
    paraphrase: "As far as it depends on you, live at peace with everyone.",
    anchors: ["depends", "you", "live", "peace", "everyone"],
    themes: ["peace", "forgiveness", "community", "love"]
  },
  {
    reference: "Micah 6:8",
    paraphrase: "The Lord has shown what is good: do justice, love mercy, and walk humbly with God.",
    anchors: ["Lord", "good", "justice", "mercy", "humbly"],
    themes: ["service", "calling", "faith", "wisdom"]
  },
  {
    reference: "Colossians 3:23",
    paraphrase: "Work wholeheartedly, as for the Lord and not for people.",
    anchors: ["work", "wholeheartedly", "Lord", "not for people"],
    themes: ["work", "discipline", "calling", "ambition"]
  },
  {
    reference: "1 Corinthians 9:24-27",
    paraphrase: "Runners train with discipline for a prize that fades, but God's people live for a crown that lasts.",
    anchors: ["runners", "discipline", "prize", "fades", "crown"],
    themes: ["discipline", "work", "resilience"]
  },
  {
    reference: "Hebrews 12:1",
    paraphrase: "Lay aside every weight and the sin that clings so closely, and run with endurance the race set before you.",
    anchors: ["weight", "sin", "endurance", "race", "before you"],
    themes: ["discipline", "resilience", "faith"]
  },
  {
    reference: "Galatians 6:9",
    paraphrase: "Do not grow weary in doing good, because in due time you will reap a harvest if you do not give up.",
    anchors: ["weary", "doing good", "due time", "harvest", "give up"],
    themes: ["resilience", "service", "work", "patience"]
  },
  {
    reference: "1 Corinthians 15:58",
    paraphrase: "Stand firm and give yourself fully to the Lord's work, because your labor in Him is not in vain.",
    anchors: ["stand firm", "Lord's work", "labor", "not in vain"],
    themes: ["resilience", "work", "calling", "faith"]
  },
  {
    reference: "Romans 12:2",
    paraphrase: "Do not be conformed to this age, but be transformed by the renewing of your mind.",
    anchors: ["conformed", "age", "transformed", "renewing", "mind"],
    themes: ["identity", "discipline", "wisdom", "faith"]
  },
  {
    reference: "Psalm 139:13-14",
    paraphrase: "God formed you inwardly and made you wonderfully, and His works are wonderful.",
    anchors: ["formed", "inwardly", "wonderfully", "works", "wonderful"],
    themes: ["identity", "healing", "joy"]
  },
  {
    reference: "John 15:5",
    paraphrase: "Jesus is the vine and His people are the branches; apart from Him they can do nothing.",
    anchors: ["vine", "branches", "apart", "nothing", "Jesus"],
    themes: ["faith", "calling", "discipline"]
  },
  {
    reference: "Psalm 16:11",
    paraphrase: "God makes known the path of life, and fullness of joy is found in His presence.",
    anchors: ["path", "life", "fullness", "joy", "presence"],
    themes: ["joy", "faith", "identity"]
  },
  {
    reference: "John 15:11",
    paraphrase: "Jesus speaks so that His joy may be in His people and their joy may be full.",
    anchors: ["Jesus", "joy", "people", "full"],
    themes: ["joy", "faith", "love"]
  },
  {
    reference: "1 Thessalonians 5:16-18",
    paraphrase: "Rejoice always, pray without ceasing, and give thanks in all circumstances.",
    anchors: ["rejoice", "pray", "thanks", "circumstances"],
    themes: ["joy", "faith", "discipline"]
  },
  {
    reference: "Hebrews 4:15-16",
    paraphrase: "Jesus sympathizes with weakness, so His people can come to the throne of grace for mercy and help.",
    anchors: ["Jesus", "weakness", "throne", "grace", "mercy"],
    themes: ["healing", "faith", "anxiety", "peace"]
  },
  {
    reference: "Jeremiah 29:11",
    paraphrase: "The Lord knows His plans for His people, plans for welfare and a future with hope.",
    anchors: ["Lord", "plans", "welfare", "future", "hope"],
    themes: ["calling", "anxiety", "faith"]
  }
] as const satisfies readonly ScriptureLibraryEntry[];

export const APPROVED_SCRIPTURE_REFERENCES = SCRIPTURE_LIBRARY.map((entry) => entry.reference);

const scriptureByReference: Map<string, ScriptureLibraryEntry> = new Map(
  SCRIPTURE_LIBRARY.map((entry) => [entry.reference, entry])
);
const MAX_REFERENCE_COUNT = 3;

export function splitReferenceCandidates(input: string): string[] {
  return input
    .split(/\s*(?:;|\+|\band\b|,\s+(?=(?:[1-3]\s)?[A-Z]))\s*/i)
    .map((part) => part.trim())
    .filter(Boolean);
}

function normalizeSingleReference(input: string): string | null {
  const trimmed = input.trim();
  return scriptureByReference.has(trimmed) ? trimmed : null;
}

export function isApprovedScriptureReference(input: string): boolean {
  return Boolean(normalizeSingleReference(input));
}

export function scriptureLibraryEntry(reference: string): ScriptureLibraryEntry | undefined {
  return scriptureByReference.get(reference.trim());
}

export function approvedScriptureParaphrase(reference: string): string | undefined {
  return scriptureLibraryEntry(reference)?.paraphrase;
}

export function approvedScriptureParaphraseForReferenceSet(referenceSet: string): string | undefined {
  const references = splitNormalizedReferences(referenceSet);
  if (!references.length) return undefined;
  const snippets = references.map((reference) => approvedScriptureParaphrase(reference));
  if (snippets.some((snippet) => !snippet)) return undefined;
  return snippets.join(" ");
}

export function normalizeReference(input: string): string {
  const normalized = splitNormalizedReferences(input);
  return normalized.length > 0 ? normalized.join("; ") : "Philippians 4:6-7";
}

export function splitNormalizedReferences(input: string): string[] {
  const normalized = splitReferenceCandidates(input)
    .slice(0, MAX_REFERENCE_COUNT)
    .map(normalizeSingleReference)
    .filter((reference): reference is string => Boolean(reference));
  return Array.from(new Set(normalized));
}

export function deterministicReference(seed: string, excludedReferences: string[] = []): string {
  const excluded = new Set(
    excludedReferences
      .flatMap((value) => splitNormalizedReferences(value))
      .filter(Boolean)
  );

  const available = APPROVED_SCRIPTURE_REFERENCES.filter((reference) => !excluded.has(reference));
  const pool = available.length > 0 ? available : APPROVED_SCRIPTURE_REFERENCES;
  const index = Math.abs(hashCode(seed)) % pool.length;
  return pool[index] ?? "Philippians 4:6-7";
}

export function deterministicReferenceForThemes(
  seed: string,
  themes: ScriptureTheme[],
  excludedReferences: string[] = []
): string {
  const excluded = new Set(
    excludedReferences
      .flatMap((value) => splitNormalizedReferences(value))
      .filter(Boolean)
  );
  const requested = new Set(themes);
  const available = SCRIPTURE_LIBRARY
    .filter((entry) => entry.themes.some((theme) => requested.has(theme)))
    .map((entry) => entry.reference)
    .filter((reference) => !excluded.has(reference));
  const pool = available.length > 0 ? available : APPROVED_SCRIPTURE_REFERENCES.filter((reference) => !excluded.has(reference));
  const fallbackPool = pool.length > 0 ? pool : APPROVED_SCRIPTURE_REFERENCES;
  const index = Math.abs(hashCode(seed)) % fallbackPool.length;
  return fallbackPool[index] ?? "Philippians 4:6-7";
}

function hashCode(value: string): number {
  let hash = 0;
  for (let index = 0; index < value.length; index += 1) {
    hash = (hash << 5) - hash + value.charCodeAt(index);
    hash |= 0;
  }
  return hash;
}
