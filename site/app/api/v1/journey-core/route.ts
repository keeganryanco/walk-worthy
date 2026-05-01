import { NextRequest, NextResponse } from "next/server";
import { generateJourneyCore } from "../../../../lib/ai/orchestrator";
import type { JourneyPackageRequest } from "../../../../lib/ai/types";
import { capturePostHogEvent } from "../../../../lib/analytics/posthog";

export const runtime = "nodejs";
export const maxDuration = 120;

function requestId(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function authorize(request: NextRequest): boolean {
  const requiredSecret = process.env.TEND_APP_SHARED_SECRET?.trim();
  if (!requiredSecret) return true;
  const provided = request.headers.get("x-tend-app-key")?.trim();
  return Boolean(provided) && provided === requiredSecret;
}

function safeFailure(message: string): { code: string; retryable: boolean; details: string } {
  if (/content_filter/i.test(message)) {
    return {
      code: "provider_content_filter",
      retryable: true,
      details: "The AI service could not finish this generation. Please try again."
    };
  }
  if (/timeout|timed out/i.test(message)) {
    return { code: "provider_timeout", retryable: true, details: "The AI service took too long. Please try again." };
  }
  if (/rate_limit|429/i.test(message)) {
    return { code: "provider_rate_limited", retryable: true, details: "The AI service is busy. Please try again soon." };
  }
  return { code: "generation_failed", retryable: true, details: "Today's Tend could not be prepared yet. Please try again." };
}

function isValidRequestPayload(payload: unknown): payload is JourneyPackageRequest {
  if (!payload || typeof payload !== "object") return false;
  const source = payload as Record<string, unknown>;
  if (!source.profile || typeof source.profile !== "object") return false;
  if (!source.journey || typeof source.journey !== "object") return false;
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

export async function POST(request: NextRequest) {
  const rid = requestId();
  console.info(`[journey-core][${rid}] request received`);

  if (!authorize(request)) {
    console.warn(`[journey-core][${rid}] unauthorized`);
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    console.warn(`[journey-core][${rid}] invalid JSON`);
    return NextResponse.json({ error: "Invalid JSON payload" }, { status: 400 });
  }

  if (!isValidRequestPayload(payload)) {
    console.warn(`[journey-core][${rid}] invalid schema`);
    return NextResponse.json({ error: "Invalid request schema" }, { status: 422 });
  }

  const typedPayload = payload as JourneyPackageRequest;
  try {
    const result = await generateJourneyCore(typedPayload);
    console.info(
      `[journey-core][${rid}] success provider=${result.provider} model=${result.model} escalated=${result.escalated} tokens=${result.usage?.totalTokens ?? 0} estCostUSD=${result.usage?.estimatedCostUSD ?? -1} diagnostics=${(result.diagnostics ?? []).join("|") || "none"}`
    );

    const distinctID = typedPayload.telemetry?.distinctID?.trim() || `anon_core_${typedPayload.journey.id}`;
    void capturePostHogEvent("ai_generation_usage", distinctID, {
      endpoint: "journey_core",
      request_id: rid,
      provider: result.provider,
      model: result.model,
      escalated: result.escalated,
      fallback_used: false,
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
      core: result.core,
      meta: {
        provider: result.provider,
        model: result.model,
        escalated: result.escalated,
        fallbackUsed: false,
        generatedAt: new Date().toISOString(),
        usage: result.usage ?? null,
        diagnostics: result.diagnostics ?? []
      }
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown core generation error";
    console.error(`[journey-core][${rid}] unhandled error: ${message}`);
    const failure = safeFailure(message);
    return NextResponse.json(
      {
        error: "Journey core generation failed",
        code: failure.code,
        retryable: failure.retryable,
        details: failure.details,
        requestId: rid
      },
      { status: failure.code === "provider_content_filter" ? 422 : 500 }
    );
  }
}
