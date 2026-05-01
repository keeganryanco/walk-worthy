import { NextRequest, NextResponse } from "next/server";
import { generateJourneySeed } from "../../../../lib/ai/bootstrap";
import type { JourneyBootstrapRequest } from "../../../../lib/ai/types";
import { capturePostHogEvent } from "../../../../lib/analytics/posthog";
import {
  LIVE_TEMPLATE_FALLBACK_STATUS,
  liveTemplateFallbackDetails,
  shouldRejectLiveTemplateFallback
} from "../../../../lib/ai/liveRoutePolicy";

export const runtime = "nodejs";
export const maxDuration = 30;

function requestId(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function authorize(request: NextRequest): boolean {
  const requiredSecret = process.env.TEND_APP_SHARED_SECRET?.trim();
  if (!requiredSecret) return true;
  const provided = request.headers.get("x-tend-app-key")?.trim();
  return Boolean(provided) && provided === requiredSecret;
}

function isValidPayload(payload: unknown): payload is JourneyBootstrapRequest {
  if (!payload || typeof payload !== "object") return false;
  const source = payload as Record<string, unknown>;
  return (
    typeof source.name === "string" &&
    typeof source.prayerIntentText === "string" &&
    (source.goalIntentText === undefined || typeof source.goalIntentText === "string") &&
    typeof source.reminderWindow === "string" &&
    (source.languageCode === undefined || typeof source.languageCode === "string") &&
    (source.localeIdentifier === undefined || typeof source.localeIdentifier === "string")
  );
}

export async function POST(request: NextRequest) {
  const rid = requestId();
  console.info(`[journey-seed][${rid}] request received`);

  if (!authorize(request)) {
    console.warn(`[journey-seed][${rid}] unauthorized`);
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    console.warn(`[journey-seed][${rid}] invalid JSON`);
    return NextResponse.json({ error: "Invalid JSON payload" }, { status: 400 });
  }

  if (!isValidPayload(payload)) {
    console.warn(`[journey-seed][${rid}] invalid schema`);
    return NextResponse.json({ error: "Invalid request schema" }, { status: 422 });
  }

  const typedPayload = payload as JourneyBootstrapRequest;
  try {
    const result = await generateJourneySeed(typedPayload);
    console.info(
      `[journey-seed][${rid}] success provider=${result.provider} model=${result.model} escalated=${result.escalated} fallback=${result.fallbackUsed} theme=${result.seed.themeKey} tokens=${result.usage?.totalTokens ?? 0} estCostUSD=${result.usage?.estimatedCostUSD ?? -1} diagnostics=${(result.diagnostics ?? []).join("|") || "none"}`
    );

    if (shouldRejectLiveTemplateFallback(result)) {
      return NextResponse.json(
        { error: "Journey seed generation failed", details: liveTemplateFallbackDetails(result.diagnostics) },
        { status: LIVE_TEMPLATE_FALLBACK_STATUS }
      );
    }

    const distinctID = typedPayload.telemetry?.distinctID?.trim() || `anon_seed_${typedPayload.name || "unknown"}`;
    void capturePostHogEvent("ai_generation_usage", distinctID, {
      endpoint: "journey_seed",
      request_id: rid,
      provider: result.provider,
      model: result.model,
      escalated: result.escalated,
      fallback_used: result.fallbackUsed,
      input_tokens: result.usage?.inputTokens ?? 0,
      output_tokens: result.usage?.outputTokens ?? 0,
      total_tokens: result.usage?.totalTokens ?? 0,
      estimated_cost_usd: result.usage?.estimatedCostUSD ?? 0,
      app_platform: typedPayload.telemetry?.platform ?? "ios",
      app_version: typedPayload.telemetry?.appVersion ?? "",
      app_build_number: typedPayload.telemetry?.buildNumber ?? "",
      diagnostics: (result.diagnostics ?? []).join("|")
    });

    return NextResponse.json({
      seed: result.seed,
      meta: {
        provider: result.provider,
        model: result.model,
        escalated: result.escalated,
        fallbackUsed: result.fallbackUsed,
        generatedAt: new Date().toISOString(),
        usage: result.usage ?? null,
        diagnostics: result.diagnostics ?? []
      }
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown seed generation error";
    console.error(`[journey-seed][${rid}] unhandled error: ${message}`);
    return NextResponse.json({ error: "Journey seed generation failed", details: message }, { status: 500 });
  }
}
