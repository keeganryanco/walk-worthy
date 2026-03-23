import { buildPrompt } from "../prompt";
import { JourneyPackageRequest } from "../types";

export async function generateWithOpenAI(input: JourneyPackageRequest, model: string, apiKey: string): Promise<string> {
    const { system, user } = buildPrompt(input);
    return generateWithOpenAIPrompt(system, user, model, apiKey);
}

export async function generateWithOpenAIPrompt(system: string, user: string, model: string, apiKey: string): Promise<string> {

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`
    },
    body: JSON.stringify({
      model,
      temperature: 0.35,
      input: [
        { role: "system", content: [{ type: "input_text", text: system }] },
        { role: "user", content: [{ type: "input_text", text: user }] }
      ]
    })
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`OpenAI request failed (${response.status}): ${errorText}`);
  }

  const body = (await response.json()) as {
    output_text?: string;
    output?: Array<{ content?: Array<{ type?: string; text?: string }> }>;
  };

  if (body.output_text && body.output_text.trim().length > 0) {
    return body.output_text;
  }

  const fallbackText = body.output
    ?.flatMap((item) => item.content ?? [])
    .filter((content) => content.type === "output_text" || content.type === "text")
    .map((content) => content.text ?? "")
    .join("\n")
    .trim();

  if (fallbackText) {
    return fallbackText;
  }

  throw new Error("OpenAI response contained no usable text output.");
}
