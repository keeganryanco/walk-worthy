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
  "Mark 10:45"
] as const;

export function normalizeReference(input: string): string {
  const trimmed = input.trim();
  return APPROVED_SCRIPTURE_REFERENCES.includes(trimmed as (typeof APPROVED_SCRIPTURE_REFERENCES)[number])
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
