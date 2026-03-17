import { fallbackPackage } from "./fallback";
import { parseAndNormalizePackage } from "./validate";
import { JourneyPackageRequest, OrchestratedResult } from "./types";
import { generateWithOpenAI } from "./providers/openai";
import { generateWithGemini } from "./providers/gemini";

type Candidate = {
  provider: "openai" | "gemini";
  model: string;
  call: (input: JourneyPackageRequest) => Promise<string>;
  escalated: boolean;
};

function buildCandidates(): Candidate[] {
  const candidates: Candidate[] = [];

  const openAIKey = process.env.OPENAI_API_KEY?.trim();
  const geminiKey = process.env.GEMINI_API_KEY?.trim();

  if (openAIKey) {
    const primaryModel = process.env.OPENAI_PRIMARY_MODEL?.trim() || "gpt-5-mini";
    candidates.push({
      provider: "openai",
      model: primaryModel,
      escalated: false,
      call: (input) => generateWithOpenAI(input, primaryModel, openAIKey)
    });
  }

  if (geminiKey) {
    const primaryModel = process.env.GEMINI_PRIMARY_MODEL?.trim() || "gemini-2.5-flash";
    candidates.push({
      provider: "gemini",
      model: primaryModel,
      escalated: false,
      call: (input) => generateWithGemini(input, primaryModel, geminiKey)
    });
  }

  if (openAIKey) {
    const escalationModel = process.env.OPENAI_ESCALATION_MODEL?.trim() || "gpt-5.1";
    candidates.push({
      provider: "openai",
      model: escalationModel,
      escalated: true,
      call: (input) => generateWithOpenAI(input, escalationModel, openAIKey)
    });
  }

  return candidates;
}

export async function generateJourneyPackage(input: JourneyPackageRequest): Promise<OrchestratedResult> {
  const candidates = buildCandidates();

  for (const candidate of candidates) {
    try {
      const raw = await candidate.call(input);
      const parsed = parseAndNormalizePackage(raw);
      if (!parsed) {
        continue;
      }

      return {
        package: parsed,
        provider: candidate.provider,
        model: candidate.model,
        escalated: candidate.escalated,
        fallbackUsed: false
      };
    } catch {
      continue;
    }
  }

  return {
    package: fallbackPackage(input),
    provider: "template",
    model: "local-template",
    escalated: true,
    fallbackUsed: true
  };
}
