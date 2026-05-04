import { NextRequest, NextResponse } from "next/server";
import { capturePostHogEvent } from "../../../../lib/analytics/posthog";
import { relayTikTokAttributionEvent } from "../../../../lib/analytics/tiktok";

export const runtime = "nodejs";

type AttributionPayload = {
  event: string;
  eventID?: string;
  timestamp?: string;
  properties?: Record<string, string | number | boolean | null>;
  telemetry?: {
    distinctID?: string;
    appVersion?: string;
    buildNumber?: string;
    platform?: string;
  };
};

function requestId(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function authorize(request: NextRequest): boolean {
  const requiredSecret = process.env.TEND_APP_SHARED_SECRET?.trim();
  if (!requiredSecret) return true;
  const provided = request.headers.get("x-tend-app-key")?.trim();
  return Boolean(provided) && provided === requiredSecret;
}

function isValidProperties(properties: unknown): properties is Record<string, string | number | boolean | null> {
  if (!properties || typeof properties !== "object" || Array.isArray(properties)) return false;
  return Object.values(properties).every((value) => {
    return (
      value === null ||
      typeof value === "string" ||
      typeof value === "number" ||
      typeof value === "boolean"
    );
  });
}

function isValidPayload(payload: unknown): payload is AttributionPayload {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) return false;
  const source = payload as Record<string, unknown>;
  if (typeof source.event !== "string" || source.event.trim().length === 0) return false;
  if (source.eventID !== undefined && typeof source.eventID !== "string") return false;
  if (source.timestamp !== undefined && typeof source.timestamp !== "string") return false;
  if (source.properties !== undefined && !isValidProperties(source.properties)) return false;
  if (source.telemetry !== undefined) {
    if (!source.telemetry || typeof source.telemetry !== "object" || Array.isArray(source.telemetry)) return false;
    const telemetry = source.telemetry as Record<string, unknown>;
    if (telemetry.distinctID !== undefined && typeof telemetry.distinctID !== "string") return false;
    if (telemetry.appVersion !== undefined && typeof telemetry.appVersion !== "string") return false;
    if (telemetry.buildNumber !== undefined && typeof telemetry.buildNumber !== "string") return false;
    if (telemetry.platform !== undefined && typeof telemetry.platform !== "string") return false;
  }
  return true;
}

function distinctIDFromPayload(payload: AttributionPayload, rid: string): string {
  const explicit = payload.telemetry?.distinctID?.trim();
  if (explicit && explicit.length > 0) return explicit;
  return `anon_attribution_${rid}`;
}

function requestIP(request: NextRequest): string | undefined {
  const forwarded = request.headers.get("x-forwarded-for")?.trim();
  if (!forwarded) return undefined;
  return forwarded.split(",")[0]?.trim();
}

function requestUserAgent(request: NextRequest): string | undefined {
  const userAgent = request.headers.get("user-agent")?.trim();
  return userAgent && userAgent.length > 0 ? userAgent : undefined;
}

export async function POST(request: NextRequest) {
  const rid = requestId();
  console.info(`[attribution][${rid}] request received`);

  if (!authorize(request)) {
    console.warn(`[attribution][${rid}] unauthorized`);
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    console.warn(`[attribution][${rid}] invalid JSON`);
    return NextResponse.json({ error: "Invalid JSON payload" }, { status: 400 });
  }

  if (!isValidPayload(payload)) {
    console.warn(`[attribution][${rid}] invalid schema`);
    return NextResponse.json({ error: "Invalid request schema" }, { status: 422 });
  }

  const typedPayload = payload as AttributionPayload;
  const distinctID = distinctIDFromPayload(typedPayload, rid);
  const event = typedPayload.event.trim();
  const eventID = typedPayload.eventID?.trim() || `${rid}-${Math.random().toString(36).slice(2, 10)}`;
  const timestamp = typedPayload.timestamp?.trim() || new Date().toISOString();
  const ip = requestIP(request);
  const userAgent = requestUserAgent(request);

  const properties = typedPayload.properties ?? {};

  const relay = await relayTikTokAttributionEvent({
    eventName: event,
    eventID,
    timestamp,
    distinctID,
    properties,
    ip,
    userAgent
  });

  void capturePostHogEvent("attribution_event", distinctID, {
    request_id: rid,
    event_name: event,
    event_id: eventID,
    relay_delivered: relay.delivered,
    relay_reason: relay.delivered ? "ok" : relay.reason,
    app_platform: typedPayload.telemetry?.platform ?? "ios",
    app_version: typedPayload.telemetry?.appVersion ?? "",
    app_build_number: typedPayload.telemetry?.buildNumber ?? ""
  });

  return NextResponse.json({
    ok: true,
    relay
  });
}

