type AttributionProperties = Record<string, string | number | boolean | null | undefined>;

type TikTokAttributionInput = {
  eventName: string;
  eventID: string;
  timestamp: string;
  distinctID: string;
  properties?: AttributionProperties;
  ip?: string;
  userAgent?: string;
};

type TikTokRelayResult =
  | { delivered: true }
  | { delivered: false; reason: "not_configured" | "unsupported_event" | "request_failed" };

const DEFAULT_EVENTS_API_URL = "https://business-api.tiktok.com/open_api/v1.3/event/track/";

function configuredValue(name: string): string | undefined {
  const value = process.env[name]?.trim();
  return value && value.length > 0 ? value : undefined;
}

function normalizeURL(rawURL: string): string {
  const trimmed = rawURL.trim();
  if (!trimmed) return DEFAULT_EVENTS_API_URL;
  return trimmed.endsWith("/") ? trimmed : `${trimmed}/`;
}

function mapEventName(eventName: string): string | undefined {
  switch (eventName) {
    case "onboarding_started":
      return "OnboardingStarted";
    case "onboarding_completed":
      return "CompleteRegistration";
    case "free_trial_started":
      return "StartTrial";
    case "trial_converted_paid":
    case "subscription_started_paid":
      return "Subscribe";
    default:
      return undefined;
  }
}

function toNumber(value: string | number | boolean | null | undefined): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return undefined;
}

function compactObject<T extends Record<string, unknown>>(value: T): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const [key, current] of Object.entries(value)) {
    if (current === undefined || current === null) continue;
    if (typeof current === "string" && current.trim().length === 0) continue;
    result[key] = current;
  }
  return result;
}

export async function relayTikTokAttributionEvent(input: TikTokAttributionInput): Promise<TikTokRelayResult> {
  const accessToken = configuredValue("TIKTOK_EVENTS_ACCESS_TOKEN");
  const eventSourceID = configuredValue("TIKTOK_CRM_EVENT_SET_ID");
  if (!accessToken || !eventSourceID) {
    return { delivered: false, reason: "not_configured" };
  }

  const mappedEventName = mapEventName(input.eventName);
  if (!mappedEventName) {
    return { delivered: false, reason: "unsupported_event" };
  }

  const source = input.properties ?? {};
  const currency = typeof source.currency === "string" ? source.currency.trim().toUpperCase() : undefined;
  const value = toNumber(source.value);
  const productID = typeof source.product_id === "string" ? source.product_id.trim() : undefined;

  const payload = compactObject({
    event_source: configuredValue("TIKTOK_EVENTS_SOURCE") ?? "crm",
    event_source_id: eventSourceID,
    event: mappedEventName,
    event_id: input.eventID,
    timestamp: input.timestamp,
    test_event_code: configuredValue("TIKTOK_EVENTS_TEST_EVENT_CODE"),
    context: compactObject({
      user: compactObject({
        external_id: input.distinctID
      }),
      ip: input.ip,
      user_agent: input.userAgent
    }),
    properties: compactObject({
      currency,
      value,
      content_id: productID
    })
  });

  const endpoint = normalizeURL(configuredValue("TIKTOK_EVENTS_API_URL") ?? DEFAULT_EVENTS_API_URL);

  try {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Access-Token": accessToken
      },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      const details = await response.text().catch(() => "");
      console.warn(`[attribution] TikTok relay failed status=${response.status} body=${details.slice(0, 400)}`);
      return { delivered: false, reason: "request_failed" };
    }

    return { delivered: true };
  } catch (error) {
    const message = error instanceof Error ? error.message : "unknown";
    console.warn(`[attribution] TikTok relay request error: ${message}`);
    return { delivered: false, reason: "request_failed" };
  }
}

