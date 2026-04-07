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
  "1 John 3:18"
] as const;

const canonicalReferencePattern = /^(?:[1-3]\s)?[A-Za-z]+(?:\s[A-Za-z]+)*\s\d{1,3}:\d{1,3}(?:-\d{1,3})?$/;

export function isCanonicalReferenceFormat(input: string): boolean {
  return canonicalReferencePattern.test(input.trim());
}

export function normalizeReference(input: string): string {
  const trimmed = input.trim();
  return APPROVED_SCRIPTURE_REFERENCES.includes(trimmed as (typeof APPROVED_SCRIPTURE_REFERENCES)[number])
    ? trimmed
    : isCanonicalReferenceFormat(trimmed)
      ? trimmed
      : "Philippians 4:6-7";
}

export function deterministicReference(seed: string, excludedReferences: string[] = []): string {
  const excluded = new Set(
    excludedReferences
      .map((value) => value.trim())
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
