import { NextRequest, NextResponse } from "next/server";
import { localizeStrings } from "../../../../lib/localization/orchestrator";
import type { LocalizationDomain } from "../../../../lib/localization/orchestrator";
import { capturePostHogEvent } from "../../../../lib/analytics/posthog";

export const runtime = "nodejs";

type LocalizeRequestPayload = {
  telemetry?: {
    distinctID?: string;
    appVersion?: string;
    buildNumber?: string;
    platform?: string;
  };
  domain: LocalizationDomain;
  targetLocale: string;
  strings: Record<string, string>;
};

function requestId(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function authorize(request: NextRequest): boolean {
  const requiredSecret = process.env.TEND_APP_SHARED_SECRET?.trim();
  if (!requiredSecret) {
    return true;
  }

  const provided = request.headers.get("x-tend-app-key")?.trim();
  return Boolean(provided) && provided === requiredSecret;
}

function isLocalizationDomain(value: unknown): value is LocalizationDomain {
  return value === "posthog_onboarding" || value === "revenuecat_paywall";
}

function isValidPayload(payload: unknown): payload is LocalizeRequestPayload {
  if (!payload || typeof payload !== "object") {
    return false;
  }

  const source = payload as Record<string, unknown>;
  if (!isLocalizationDomain(source.domain)) {
    return false;
  }
  if (typeof source.targetLocale !== "string") {
    return false;
  }
  if (!source.strings || typeof source.strings !== "object" || Array.isArray(source.strings)) {
    return false;
  }
  if (source.telemetry !== undefined && (typeof source.telemetry !== "object" || Array.isArray(source.telemetry))) {
    return false;
  }
  if (source.telemetry && typeof source.telemetry === "object") {
    const telemetry = source.telemetry as Record<string, unknown>;
    if (telemetry.distinctID !== undefined && typeof telemetry.distinctID !== "string") return false;
    if (telemetry.appVersion !== undefined && typeof telemetry.appVersion !== "string") return false;
    if (telemetry.buildNumber !== undefined && typeof telemetry.buildNumber !== "string") return false;
    if (telemetry.platform !== undefined && typeof telemetry.platform !== "string") return false;
  }

  for (const value of Object.values(source.strings as Record<string, unknown>)) {
    if (typeof value !== "string") {
      return false;
    }
  }

  return true;
}

function normalizeLocale(input: string): "en" | "es" | "pt-br" | "ja" | "ko" {
  const normalized = input.trim().toLowerCase();
  if (normalized.startsWith("es")) return "es";
  if (normalized.startsWith("pt")) return "pt-br";
  if (normalized.startsWith("ja")) return "ja";
  if (normalized.startsWith("ko")) return "ko";
  return "en";
}

function telemetryDistinctID(payload: LocalizeRequestPayload | null, rid: string): string {
  return payload?.telemetry?.distinctID?.trim() || `anon_localize_${rid}`;
}

export async function POST(request: NextRequest) {
  const rid = requestId();
  console.info(`[localize][${rid}] request received`);

  if (!authorize(request)) {
    console.warn(`[localize][${rid}] unauthorized`);
    void capturePostHogEvent("localization_request", `anon_localize_${rid}`, {
      request_id: rid,
      outcome: "unauthorized"
    });
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    console.warn(`[localize][${rid}] invalid JSON`);
    void capturePostHogEvent("localization_request", `anon_localize_${rid}`, {
      request_id: rid,
      outcome: "invalid_json"
    });
    return NextResponse.json({ error: "Invalid JSON payload" }, { status: 400 });
  }

  if (!isValidPayload(payload)) {
    console.warn(`[localize][${rid}] invalid schema`);
    void capturePostHogEvent("localization_request", `anon_localize_${rid}`, {
      request_id: rid,
      outcome: "invalid_schema"
    });
    return NextResponse.json({ error: "Invalid request schema" }, { status: 422 });
  }

  const typedPayload = payload as LocalizeRequestPayload;
  const distinctID = telemetryDistinctID(typedPayload, rid);
  const normalizedLocale = normalizeLocale(typedPayload.targetLocale);

  try {
    const result = await localizeStrings(typedPayload);

    console.info(
      `[localize][${rid}] success provider=${result.meta.provider} model=${result.meta.model} cached=${result.meta.cached} fallback=${result.meta.fallbackUsed}`
    );

    void capturePostHogEvent("localization_request", distinctID, {
      request_id: rid,
      domain: typedPayload.domain,
      target_locale: normalizedLocale,
      key_count: Object.keys(typedPayload.strings).length,
      outcome: "success",
      provider: result.meta.provider,
      model: result.meta.model,
      cached: result.meta.cached,
      fallback_used: result.meta.fallbackUsed,
      app_platform: typedPayload.telemetry?.platform ?? "ios",
      app_version: typedPayload.telemetry?.appVersion ?? "",
      app_build_number: typedPayload.telemetry?.buildNumber ?? ""
    });

    return NextResponse.json(result);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown localization error";
    console.error(`[localize][${rid}] unhandled error: ${message}`);

    void capturePostHogEvent("localization_request", distinctID, {
      request_id: rid,
      domain: typedPayload.domain,
      target_locale: normalizedLocale,
      key_count: Object.keys(typedPayload.strings).length,
      outcome: "error",
      provider: "template",
      model: "route_error",
      cached: false,
      fallback_used: true,
      app_platform: typedPayload.telemetry?.platform ?? "ios",
      app_version: typedPayload.telemetry?.appVersion ?? "",
      app_build_number: typedPayload.telemetry?.buildNumber ?? ""
    });

    return NextResponse.json({ error: "Localization failed", details: message }, { status: 500 });
  }
}
