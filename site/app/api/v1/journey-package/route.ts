import { NextRequest, NextResponse } from "next/server";
import { generateJourneyPackage } from "../../../../lib/ai/orchestrator";
import { JourneyPackageRequest } from "../../../../lib/ai/types";

export const runtime = "nodejs";

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
    typeof journey.category === "string"
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
  if (!authorize(request)) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON payload" }, { status: 400 });
  }

  if (!isValidRequestPayload(payload)) {
    return NextResponse.json({ error: "Invalid request schema" }, { status: 422 });
  }

  const result = await generateJourneyPackage(payload);

  return NextResponse.json({
    package: result.package,
    meta: {
      provider: result.provider,
      model: result.model,
      escalated: result.escalated,
      fallbackUsed: result.fallbackUsed,
      generatedAt: new Date().toISOString()
    }
  });
}
