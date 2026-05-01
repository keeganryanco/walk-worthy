import { buildPrompt } from "../prompt";
import type { AITokenUsage, JourneyPackageRequest } from "../types";

export interface ProviderGenerationResult {
  text: string;
  usage?: AITokenUsage;
}

const OPENAI_MAX_OUTPUT_TOKENS = 2600;

function supportsTemperature(model: string): boolean {
  return !/^gpt-5(?:\.|-|$)/i.test(model.trim());
}

export function buildOpenAIResponsesRequestBody(system: string, user: string, model: string): Record<string, unknown> {
  return {
    model,
    ...(supportsTemperature(model) ? { temperature: 0.35 } : {}),
    max_output_tokens: OPENAI_MAX_OUTPUT_TOKENS,
    input: [
      { role: "system", content: [{ type: "input_text", text: system }] },
      { role: "user", content: [{ type: "input_text", text: user }] }
    ]
  };
}

export async function generateWithOpenAI(
  input: JourneyPackageRequest,
  model: string,
  apiKey: string
): Promise<ProviderGenerationResult> {
    const { system, user } = buildPrompt(input);
    return generateWithOpenAIPrompt(system, user, model, apiKey);
}

export async function generateWithOpenAIPrompt(
  system: string,
  user: string,
  model: string,
  apiKey: string
): Promise<ProviderGenerationResult> {

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`
    },
    body: JSON.stringify(buildOpenAIResponsesRequestBody(system, user, model))
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`OpenAI request failed (${response.status}): ${errorText}`);
  }

  const body = (await response.json()) as {
    status?: string;
    incomplete_details?: { reason?: string | null } | null;
    output_text?: string;
    output?: Array<{ content?: Array<{ type?: string; text?: string }> }>;
    usage?: {
      input_tokens?: number;
      output_tokens?: number;
      total_tokens?: number;
    };
  };

  const usage: AITokenUsage | undefined = body.usage
    ? {
        inputTokens: body.usage.input_tokens,
        outputTokens: body.usage.output_tokens,
        totalTokens: body.usage.total_tokens
      }
    : undefined;

  if (body.status && body.status !== "completed") {
    const reason = body.incomplete_details?.reason ?? "unknown";
    throw new Error(`OpenAI response incomplete (status=${body.status}, reason=${reason})`);
  }

  if (body.output_text && body.output_text.trim().length > 0) {
    return { text: body.output_text, usage };
  }

  const fallbackText = body.output
    ?.flatMap((item) => item.content ?? [])
    .filter((content) => content.type === "output_text" || content.type === "text")
    .map((content) => content.text ?? "")
    .join("\n")
    .trim();

  if (fallbackText) {
    return { text: fallbackText, usage };
  }

  throw new Error("OpenAI response contained no usable text output.");
}
