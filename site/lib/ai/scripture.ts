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
  "Psalm 27:14"
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

export function deterministicReference(seed: string): string {
  const index = Math.abs(hashCode(seed)) % APPROVED_SCRIPTURE_REFERENCES.length;
  return APPROVED_SCRIPTURE_REFERENCES[index];
}

function hashCode(value: string): number {
  let hash = 0;
  for (let index = 0; index < value.length; index += 1) {
    hash = (hash << 5) - hash + value.charCodeAt(index);
    hash |= 0;
  }
  return hash;
}
