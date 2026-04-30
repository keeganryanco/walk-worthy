export const APPROVED_SCRIPTURE_REFERENCES = [
  "Galatians 6:9",
  "1 Corinthians 15:58",
  "Joshua 1:9",
  "2 Timothy 1:7",
  "Philippians 4:6-7",
  "Isaiah 26:3",
  "Colossians 3:23",
  "1 Corinthians 9:27",
  "Galatians 5:13",
  "Mark 10:45",
  "Romans 12:2",
  "Proverbs 3:5-6",
  "James 1:5",
  "Psalm 23:1-3",
  "Psalm 46:10",
  "Psalm 121:1-2",
  "Psalm 119:105",
  "Isaiah 40:31",
  "Lamentations 3:22-23",
  "Matthew 11:28",
  "Matthew 6:33",
  "Matthew 6:34",
  "Matthew 5:16",
  "Matthew 7:7",
  "John 15:5",
  "John 14:27",
  "John 16:33",
  "Romans 8:28",
  "Romans 12:12",
  "Romans 5:3-4",
  "Romans 15:13",
  "1 Corinthians 10:13",
  "2 Corinthians 5:7",
  "2 Corinthians 12:9",
  "Ephesians 2:10",
  "Ephesians 4:2",
  "Ephesians 4:32",
  "Philippians 1:6",
  "Philippians 4:8",
  "Colossians 3:12",
  "1 Thessalonians 5:16-18",
  "2 Thessalonians 3:13",
  "Hebrews 12:1",
  "Hebrews 11:1",
  "Hebrews 10:24",
  "James 1:2-4",
  "James 1:22",
  "James 4:8",
  "1 Peter 5:7",
  "1 Peter 4:10",
  "2 Peter 1:5-7",
  "1 John 4:18",
  "1 John 1:9",
  "Micah 6:8",
  "Proverbs 16:3",
  "Proverbs 27:17",
  "Ecclesiastes 4:9-10",
  "Psalm 37:4-5",
  "Psalm 34:8",
  "Psalm 27:14",
  "Deuteronomy 31:6",
  "Psalm 4:8",
  "Psalm 56:3-4",
  "Psalm 62:8",
  "Psalm 90:14",
  "Psalm 94:19",
  "Psalm 118:24",
  "Psalm 143:8",
  "Proverbs 4:23",
  "Proverbs 11:25",
  "Proverbs 18:10",
  "Isaiah 30:15",
  "Isaiah 30:18",
  "Isaiah 41:10",
  "Jeremiah 17:7-8",
  "Habakkuk 3:19",
  "Zephaniah 3:17",
  "Matthew 9:37-38",
  "Matthew 22:37-39",
  "Matthew 28:19-20",
  "Luke 1:37",
  "Luke 6:36",
  "Luke 16:10",
  "John 8:12",
  "John 10:10",
  "John 13:34-35",
  "John 14:1",
  "John 15:12",
  "Acts 20:35",
  "Romans 8:25",
  "Romans 12:10",
  "Romans 12:21",
  "1 Corinthians 13:4-7",
  "1 Corinthians 16:13-14",
  "2 Corinthians 4:16-18",
  "2 Corinthians 9:6-8",
  "Galatians 6:2",
  "Ephesians 3:20",
  "Philippians 2:3-4",
  "Philippians 2:13",
  "Philippians 3:13-14",
  "Philippians 4:13",
  "1 Thessalonians 5:11",
  "2 Thessalonians 1:3",
  "Hebrews 6:10",
  "Hebrews 6:15",
  "Hebrews 13:5-6",
  "James 5:7-8",
  "1 Peter 3:8",
  "1 Peter 4:8",
  "1 John 3:18",
  "Genesis 2:24",
  "Deuteronomy 6:6-7",
  "Psalm 16:11",
  "Psalm 25:4-5",
  "Psalm 34:18",
  "Psalm 55:12-14",
  "Psalm 55:22",
  "Psalm 73:26",
  "Psalm 139:13-14",
  "Psalm 147:3",
  "Nehemiah 8:10",
  "Proverbs 2:6",
  "Proverbs 4:26",
  "Proverbs 12:18",
  "Proverbs 15:1",
  "Proverbs 15:22",
  "Proverbs 16:2",
  "Proverbs 18:21",
  "Proverbs 21:5",
  "Proverbs 22:6",
  "Proverbs 29:25",
  "Ecclesiastes 3:1",
  "Isaiah 43:1-2",
  "Isaiah 55:8-9",
  "Jeremiah 29:11",
  "Matthew 5:4",
  "Matthew 6:25-34",
  "Matthew 25:21",
  "Luke 6:27-28",
  "Luke 12:15",
  "John 15:11",
  "John 15:16",
  "Romans 8:1",
  "Romans 8:15",
  "Romans 12:17-18",
  "Romans 12:18",
  "1 Corinthians 9:24-27",
  "1 Corinthians 10:31",
  "2 Corinthians 1:3-4",
  "2 Corinthians 10:5",
  "Galatians 1:10",
  "Galatians 5:22-23",
  "Ephesians 4:15",
  "Ephesians 4:26-27",
  "Ephesians 4:31-32",
  "Ephesians 5:25",
  "Ephesians 6:4",
  "Philippians 4:11-13",
  "Colossians 3:17",
  "Colossians 3:19",
  "1 Timothy 4:12",
  "2 Timothy 2:5",
  "Hebrews 4:15-16",
  "Hebrews 12:11",
  "James 1:19-20",
  "James 3:17",
  "1 Peter 3:7",
  "1 Peter 5:6-7",
  "Revelation 21:4"
] as const;

const canonicalReferencePattern = /^(?:[1-3]\s)?[A-Za-z]+(?:\s[A-Za-z]+)*\s\d{1,3}:\d{1,3}(?:-\d{1,3})?$/;
const MAX_REFERENCE_COUNT = 3;

export function isCanonicalReferenceFormat(input: string): boolean {
  return canonicalReferencePattern.test(input.trim());
}

export function splitReferenceCandidates(input: string): string[] {
  return input
    .split(/\s*(?:;|\+|\band\b|,\s+(?=(?:[1-3]\s)?[A-Z]))\s*/i)
    .map((part) => part.trim())
    .filter(Boolean);
}

function normalizeSingleReference(input: string): string | null {
  const trimmed = input.trim();
  if (APPROVED_SCRIPTURE_REFERENCES.includes(trimmed as (typeof APPROVED_SCRIPTURE_REFERENCES)[number])) {
    return trimmed;
  }
  return isCanonicalReferenceFormat(trimmed) ? trimmed : null;
}

export function normalizeReference(input: string): string {
  const parts = splitReferenceCandidates(input).slice(0, MAX_REFERENCE_COUNT);
  const normalized = parts
    .map(normalizeSingleReference)
    .filter((reference): reference is string => Boolean(reference));
  const unique = Array.from(new Set(normalized));
  return unique.length > 0 ? unique.join("; ") : "Philippians 4:6-7";
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
  return pool[index];
}

function hashCode(value: string): number {
  let hash = 0;
  for (let index = 0; index < value.length; index += 1) {
    hash = (hash << 5) - hash + value.charCodeAt(index);
    hash |= 0;
  }
  return hash;
}
