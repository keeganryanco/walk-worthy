type CaptureProperties = Record<string, string | number | boolean | null | undefined>;

function normalizeHost(host: string): string {
  const trimmed = host.trim().replace(/\/+$/, "");
  if (!trimmed) return "https://us.i.posthog.com";
  if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) return trimmed;
  return `https://${trimmed}`;
}

function toCaptureURL(host: string): string {
  return `${normalizeHost(host)}/capture/`;
}

export async function capturePostHogEvent(
  event: string,
  distinctID: string,
  properties: CaptureProperties
): Promise<void> {
  const apiKey =
    process.env.POSTHOG_API_KEY?.trim() ||
    process.env.POSTHOG_PROJECT_API_KEY?.trim() ||
    "";
  if (!apiKey) return;

  const host = process.env.POSTHOG_HOST?.trim() || "https://us.i.posthog.com";
  const body = {
    api_key: apiKey,
    event,
    properties: {
      distinct_id: distinctID,
      ...properties
    }
  };

  try {
    await fetch(toCaptureURL(host), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body)
    });
  } catch {
    // Intentionally non-blocking telemetry
  }
}

