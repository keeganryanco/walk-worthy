import { NextRequest, NextResponse } from "next/server";
import { generateJourneyBootstrap } from "../../../../lib/ai/bootstrap";
import { JourneyBootstrapRequest } from "../../../../lib/ai/types";

export const runtime = "nodejs";

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
    typeof source.goalIntentText === "string" &&
    typeof source.reminderWindow === "string"
  );
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

  if (!isValidPayload(payload)) {
    return NextResponse.json({ error: "Invalid request schema" }, { status: 422 });
  }

  const result = await generateJourneyBootstrap(payload);

  return NextResponse.json({
    bootstrap: result.bootstrap,
    meta: {
      provider: result.provider,
      model: result.model,
      escalated: result.escalated,
      fallbackUsed: result.fallbackUsed,
      generatedAt: new Date().toISOString()
    }
  });
}
