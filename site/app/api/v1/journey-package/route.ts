import { NextRequest, NextResponse } from "next/server";
import { generateJourneyPackage } from "../../../../lib/ai/orchestrator";
import type { JourneyPackageRequest } from "../../../../lib/ai/types";
import { capturePostHogEvent } from "../../../../lib/analytics/posthog";

export const runtime = "nodejs";
export const maxDuration = 60;

function requestId(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function isValidRequestPayload(payload: unknown): payload is JourneyPackageRequest {
  if (!payload || typeof payload !== "object") {
    return false;
  }

  const source = payload as Record<string, unknown>;
  if (!source.profile || typeof source.profile !== "object") {
    return false;
  }
  if (!source.journey || typeof source.journey !== "object") {
    return false;
  }

  const profile = source.profile as Record<string, unknown>;
  const journey = source.journey as Record<string, unknown>;

  return (
    typeof profile.prayerFocus === "string" &&
    typeof profile.growthGoal === "string" &&
    typeof journey.id === "string" &&
    typeof journey.title === "string" &&
    typeof journey.category === "string" &&
    (source.languageCode === undefined || typeof source.languageCode === "string") &&
    (source.localeIdentifier === undefined || typeof source.localeIdentifier === "string")
  );
}

function authorize(request: NextRequest): boolean {
  const requiredSecret = process.env.TEND_APP_SHARED_SECRET?.trim();
  if (!requiredSecret) {
    return true;
  }

  const provided = request.headers.get("x-tend-app-key")?.trim();
  return Boolean(provided) && provided === requiredSecret;
}

export async function POST(request: NextRequest) {
  const rid = requestId();
  console.info(`[journey-package][${rid}] request received`);

  if (!authorize(request)) {
    console.warn(`[journey-package][${rid}] unauthorized`);
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    console.warn(`[journey-package][${rid}] invalid JSON`);
    return NextResponse.json({ error: "Invalid JSON payload" }, { status: 400 });
  }

  if (!isValidRequestPayload(payload)) {
    console.warn(`[journey-package][${rid}] invalid schema`);
    return NextResponse.json({ error: "Invalid request schema" }, { status: 422 });
  }

  const typedPayload = payload as JourneyPackageRequest;
  console.info(
    `[journey-package][${rid}] start generation journeyId=${typedPayload.journey.id} completionCount=${typedPayload.completionCount ?? 0} cycleCount=${typedPayload.cycleCount ?? 0}`
  );

  try {
    const result = await generateJourneyPackage(typedPayload);
    console.info(
      `[journey-package][${rid}] success provider=${result.provider} model=${result.model} escalated=${result.escalated} fallback=${result.fallbackUsed} tokens=${result.usage?.totalTokens ?? 0} estCostUSD=${result.usage?.estimatedCostUSD ?? -1} diagnostics=${(result.diagnostics ?? []).join("|") || "none"}`
    );

    const distinctID =
      typedPayload.telemetry?.distinctID?.trim() ||
      `anon_journey_${typedPayload.journey.id}`;
    const estimatedCostUSD =
      typeof result.usage?.estimatedCostUSD === "number"
        ? result.usage.estimatedCostUSD
        : 0;
    const projectedMonthlyCostUSD = Number((estimatedCostUSD * (1095 / 12)).toFixed(2));
    const projectedYearlyCostUSD = Number((estimatedCostUSD * 1095).toFixed(2));

    void capturePostHogEvent("ai_generation_usage", distinctID, {
      endpoint: "journey_package",
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
      completion_count: typedPayload.completionCount ?? 0,
      cycle_count: typedPayload.cycleCount ?? 0,
      app_platform: typedPayload.telemetry?.platform ?? "ios",
      app_version: typedPayload.telemetry?.appVersion ?? "",
      app_build_number: typedPayload.telemetry?.buildNumber ?? "",
      has_follow_through_context: Boolean(typedPayload.followThroughContext),
      has_recent_signals: (typedPayload.recentJourneySignals?.length ?? 0) > 0,
      diagnostics: (result.diagnostics ?? []).join("|")
    });

    return NextResponse.json({
      package: result.package,
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
    const message = error instanceof Error ? error.message : "Unknown package generation error";
    console.error(`[journey-package][${rid}] unhandled error: ${message}`);
    return NextResponse.json({ error: "Journey package generation failed", details: message }, { status: 500 });
  }
}
