import { NextRequest, NextResponse } from "next/server";
import { localizeStrings } from "../../../../lib/localization/orchestrator";
import type { LocalizationDomain } from "../../../../lib/localization/orchestrator";

export const runtime = "nodejs";

type LocalizeRequestPayload = {
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

  for (const value of Object.values(source.strings as Record<string, unknown>)) {
    if (typeof value !== "string") {
      return false;
    }
  }

  return true;
}

export async function POST(request: NextRequest) {
  const rid = requestId();
  console.info(`[localize][${rid}] request received`);

  if (!authorize(request)) {
    console.warn(`[localize][${rid}] unauthorized`);
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    console.warn(`[localize][${rid}] invalid JSON`);
    return NextResponse.json({ error: "Invalid JSON payload" }, { status: 400 });
  }

  if (!isValidPayload(payload)) {
    console.warn(`[localize][${rid}] invalid schema`);
    return NextResponse.json({ error: "Invalid request schema" }, { status: 422 });
  }

  try {
    const result = await localizeStrings(payload);

    console.info(
      `[localize][${rid}] success provider=${result.meta.provider} model=${result.meta.model} cached=${result.meta.cached} fallback=${result.meta.fallbackUsed}`
    );

    return NextResponse.json(result);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown localization error";
    console.error(`[localize][${rid}] unhandled error: ${message}`);
    return NextResponse.json({ error: "Localization failed", details: message }, { status: 500 });
  }
}
