export const LIVE_TEMPLATE_FALLBACK_STATUS = 502;

export function shouldRejectLiveTemplateFallback(result: { fallbackUsed: boolean }): boolean {
  return result.fallbackUsed;
}

export function liveTemplateFallbackDetails(
  diagnostics: readonly string[] | undefined,
  fallbackMessage = "template fallback disabled"
): string {
  const joined = diagnostics?.filter(Boolean).join("|") ?? "";
  return joined || fallbackMessage;
}
