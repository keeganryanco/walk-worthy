import { NextRequest, NextResponse } from "next/server";
import { generateJourneyBootstrap } from "../../../../lib/ai/bootstrap";
import type { JourneyBootstrapRequest } from "../../../../lib/ai/types";
import { capturePostHogEvent } from "../../../../lib/analytics/posthog";
import {
  LIVE_TEMPLATE_FALLBACK_STATUS,
  liveTemplateFallbackDetails,
  shouldRejectLiveTemplateFallback
} from "../../../../lib/ai/liveRoutePolicy";

export const runtime = "nodejs";
export const maxDuration = 180;

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
  console.info(`[journey-bootstrap][${rid}] request received`);

  if (!authorize(request)) {
    console.warn(`[journey-bootstrap][${rid}] unauthorized`);
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    console.warn(`[journey-bootstrap][${rid}] invalid JSON`);
    return NextResponse.json({ error: "Invalid JSON payload" }, { status: 400 });
  }

  if (!isValidPayload(payload)) {
    console.warn(`[journey-bootstrap][${rid}] invalid schema`);
    return NextResponse.json({ error: "Invalid request schema" }, { status: 422 });
  }

  const typedPayload = payload as JourneyBootstrapRequest;
  console.info(
    `[journey-bootstrap][${rid}] start generation reminderWindow=${typedPayload.reminderWindow} prayerLen=${typedPayload.prayerIntentText.length} goalLen=${typedPayload.goalIntentText?.length ?? 0}`
  );

  try {
    const result = await generateJourneyBootstrap(typedPayload);
    console.info(
      `[journey-bootstrap][${rid}] success provider=${result.provider} model=${result.model} escalated=${result.escalated} fallback=${result.fallbackUsed} theme=${result.bootstrap.themeKey} tokens=${result.usage?.totalTokens ?? 0} estCostUSD=${result.usage?.estimatedCostUSD ?? -1} diagnostics=${(result.diagnostics ?? []).join("|") || "none"}`
    );

    if (shouldRejectLiveTemplateFallback(result)) {
      return NextResponse.json(
        { error: "Journey bootstrap failed", details: liveTemplateFallbackDetails(result.diagnostics) },
        { status: LIVE_TEMPLATE_FALLBACK_STATUS }
      );
    }

    const distinctID = typedPayload.telemetry?.distinctID?.trim() || `anon_bootstrap_${typedPayload.name || "unknown"}`;
    const estimatedCostUSD =
      typeof result.usage?.estimatedCostUSD === "number"
        ? result.usage.estimatedCostUSD
        : 0;
    const projectedMonthlyCostUSD = Number((estimatedCostUSD * (1095 / 12)).toFixed(2));
    const projectedYearlyCostUSD = Number((estimatedCostUSD * 1095).toFixed(2));

    void capturePostHogEvent("ai_generation_usage", distinctID, {
      endpoint: "journey_bootstrap",
      request_id: rid,
      provider: result.provider,
      model: result.model,
      escalated: result.escalated,
      fallback_used: result.fallbackUsed,
      input_tokens: result.usage?.inputTokens ?? 0,
      output_tokens: result.usage?.outputTokens ?? 0,
      total_tokens: result.usage?.totalTokens ?? 0,
      estimated_cost_usd: estimatedCostUSD,
      cost_guardrail_package_exceeded: estimatedCostUSD > 0.035,
      projected_monthly_cost_usd: projectedMonthlyCostUSD,
      cost_guardrail_monthly_exceeded: projectedMonthlyCostUSD > 1,
      projected_yearly_cost_usd: projectedYearlyCostUSD,
      cost_guardrail_yearly_exceeded: projectedYearlyCostUSD > 30,
      theme_key: result.bootstrap.themeKey,
      app_platform: typedPayload.telemetry?.platform ?? "ios",
      app_version: typedPayload.telemetry?.appVersion ?? "",
      app_build_number: typedPayload.telemetry?.buildNumber ?? "",
      diagnostics: (result.diagnostics ?? []).join("|")
    });

    return NextResponse.json({
      bootstrap: result.bootstrap,
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
    const message = error instanceof Error ? error.message : "Unknown bootstrap error";
    console.error(`[journey-bootstrap][${rid}] unhandled error: ${message}`);
    return NextResponse.json({ error: "Journey bootstrap failed", details: message }, { status: 500 });
  }
}
