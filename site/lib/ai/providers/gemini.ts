import { buildPrompt } from "../prompt";
import { AITokenUsage, JourneyPackageRequest } from "../types";
import type { ProviderGenerationResult } from "./openai";

export async function generateWithGemini(
  input: JourneyPackageRequest,
  model: string,
  apiKey: string
): Promise<ProviderGenerationResult> {
  const { system, user } = buildPrompt(input);
  return generateWithGeminiPrompt(system, user, model, apiKey);
}

export async function generateWithGeminiPrompt(
  system: string,
  user: string,
  model: string,
  apiKey: string
): Promise<ProviderGenerationResult> {
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;

  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey
    },
    body: JSON.stringify({
      systemInstruction: {
        parts: [{ text: system }]
      },
      contents: [{ role: "user", parts: [{ text: user }] }],
      generationConfig: {
        temperature: 0.35,
        maxOutputTokens: 1400,
        responseMimeType: "application/json"
      }
    })
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Gemini request failed (${response.status}): ${errorText}`);
  }

  const body = (await response.json()) as {
    candidates?: Array<{
      finishReason?: string;
      content?: { parts?: Array<{ text?: string }> };
    }>;
    usageMetadata?: {
      promptTokenCount?: number;
      candidatesTokenCount?: number;
      totalTokenCount?: number;
    };
  };

  const usage: AITokenUsage | undefined = body.usageMetadata
    ? {
        inputTokens: body.usageMetadata.promptTokenCount,
        outputTokens: body.usageMetadata.candidatesTokenCount,
        totalTokens: body.usageMetadata.totalTokenCount
      }
    : undefined;

  const finishReason = body.candidates?.[0]?.finishReason;
  if (finishReason && finishReason !== "STOP") {
    throw new Error(`Gemini response incomplete (finishReason=${finishReason})`);
  }

  const text = body.candidates?.[0]?.content?.parts?.map((part) => part.text ?? "").join("\n").trim();
  if (!text) {
    throw new Error("Gemini response contained no usable text output.");
  }

  return { text, usage };
}
