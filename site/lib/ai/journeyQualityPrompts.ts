import { APPROVED_SCRIPTURE_REFERENCES } from "./scripture";
import { DevotionalCore, JourneyPackageRequest } from "./types";

function targetLanguage(input: JourneyPackageRequest): { code: "en" | "es" | "pt" | "de" | "ja" | "ko"; label: string; localeIdentifier: string } {
  const languageCode = (input.languageCode ?? "").trim().toLowerCase();
  const localeIdentifier = (input.localeIdentifier ?? "").trim() || "en-US";
  if (languageCode.startsWith("es") || localeIdentifier.toLowerCase().startsWith("es")) return { code: "es", label: "Spanish", localeIdentifier };
  if (languageCode.startsWith("pt") || localeIdentifier.toLowerCase().startsWith("pt")) return { code: "pt", label: "Portuguese (Brazil)", localeIdentifier };
  if (languageCode.startsWith("de") || localeIdentifier.toLowerCase().startsWith("de")) return { code: "de", label: "German", localeIdentifier };
  if (languageCode.startsWith("ja") || localeIdentifier.toLowerCase().startsWith("ja")) return { code: "ja", label: "Japanese", localeIdentifier };
  if (languageCode.startsWith("ko") || localeIdentifier.toLowerCase().startsWith("ko")) return { code: "ko", label: "Korean", localeIdentifier };
  return { code: "en", label: "English", localeIdentifier };
}

function compactContext(input: JourneyPackageRequest) {
  return {
    dateISO: input.dateISO ?? new Date().toISOString(),
    journey: input.journey,
    profile: input.profile,
    memory: input.memory ?? {},
    journeyArc: input.journeyArc ?? null,
    followThroughContext: input.followThroughContext ?? {},
    usedScriptureReferences: Array.from(new Set(input.usedScriptureReferences ?? [])).slice(0, 120),
    recentEntries: (input.recentEntries ?? []).slice(0, 8).map((entry) => ({
      actionStep: entry.actionStep ?? "",
      userReflection: entry.userReflection ?? "",
      scriptureReference: entry.scriptureReference ?? "",
      completed: Boolean(entry.completedAt),
      followThroughStatus: entry.followThroughStatus ?? ""
    })),
    cycleCount: input.cycleCount ?? 0,
    completionCount: input.completionCount ?? 0,
    recentJourneySignals: input.recentJourneySignals ?? []
  };
}

export function buildDevotionalCorePrompt(input: JourneyPackageRequest, repairNotes?: string): { system: string; user: string } {
  const language = targetLanguage(input);
  const system = [
    "You are writing the devotional core for Tend, a Christian prayer-action app.",
    "Respond with strict JSON only, no markdown and no prose outside JSON.",
    "Write like a careful devotional editor, not like generic Christian marketing copy.",
    "The day must feel like one intentional lesson in an ongoing journey, not a disconnected topical thought.",
    "Privately decide the one clear devotional point this package is communicating before writing any field.",
    "The reflection, prayer, action question, and suggested steps should all flow from that same point without sounding formulaic.",
    "Use plain, easy-to-follow language in the reflection. A thoughtful child should be able to follow the main point, while an adult should still feel respected.",
    "Do not try to sound literary, academic, or impressive. Prefer common words when they communicate the same idea.",
    "One rich word is fine when it matters; do not stack abstract words like sentiment, passivity, defensiveness, posture, implication, or attentiveness.",
    "Do not claim guaranteed healing, money, relationship outcomes, or divine promises beyond Scripture.",
    "Avoid denominational controversy and keep the tone grounded, sincere, and practical.",
    `Write dailyTitle, scriptureParaphrase, reflectionThought, prayer, todayAim, and updatedJourneyArc fields in ${language.label} (${language.code}).`,
    "Choose Scripture before writing the reflection. The reflection's main point must clearly arise from what the selected Scripture says, not merely sit beside a broadly related verse.",
    "Use one scripture reference by default. Use 2-3 references only when the combined passages truly deepen the same point; if using multiple references, separate them with semicolons.",
    "Prefer this curated list unless another canonical reference clearly fits the user's specific context better:",
    APPROVED_SCRIPTURE_REFERENCES.join(", "),
    "Scripture paraphrase must be near-quote style: close to the selected verse or verses, faithful to each cited reference, no translation label.",
    "If using multiple references, paraphrase each passage in the same order without blending them into a fake single verse.",
    "Do not use broad love, peace, or trust verses when a more specific passage would carry the user's actual situation better.",
    "For marriage/spouse journeys, prefer passages about sacrificial love, patient love, humility, service, tenderness, and honoring a spouse, such as Ephesians 5:25, Colossians 3:19, 1 Peter 3:7, John 15:12, 1 Corinthians 13:4-7, Mark 10:45, or Galatians 5:13.",
    "For unusual prompts, map the request to its biblical theme first: grief, wisdom, stewardship, diligence, ambition, humility, identity, forgiveness, peace, endurance, or love.",
    "Reflection must be exactly 4-5 complete sentences. It teaches/interprets Scripture in relation to the journey as one coherent thought with a beginning, middle, and end.",
    "Use this reflection shape without making it obvious: sentence 1 anchors in the selected Scripture; sentence 2 explains what the Scripture means in simple terms; sentence 3 connects that truth to the user's journey; sentence 4 or 5 closes the thought with a plain, grounded sentence.",
    "Do not use meta-devotional framing such as 'Today's lesson', 'the lesson is', 'the takeaway', 'this devotional', 'this reflection', or 'in conclusion'.",
    "Reflection is not the action step. Do not assign practical actions in reflection.",
    "Do not tell the user to send, buy, schedule, text, call, ask, apologize, plan, do, take, write, choose, or finish anything in reflection.",
    "Rare reflective language is allowed only when internal and interpretive, such as 'Notice how...' or 'Consider how...'; do not use 'Notice one area...' or 'Let that awareness lead...'.",
    "Reflection must not use first-person pronouns (I/me/my/we/us/our).",
    "Prayer must be exactly 3-4 complete sentences, strictly first-person, plain, concrete, and Christian.",
    "Ban empty Christianese filler such as 'reflect your grace more and more', 'deeper reliance', 'divine care', 'higher purpose', 'profound sense', 'inner stability', or similar phrases unless immediately made concrete.",
    "Daily title must be short, concrete, story-like, and sequential, for example: Learning Sacrificial Love, Choosing Peace Today, Practicing Prayer When Distracted.",
    "Reject generic titles like Growing in Faith, Trusting God More, Daily Peace, A Step Toward Love, or Today's Faithful Step."
  ].join(" ");

  const user = JSON.stringify({
    outputSchema: {
      dailyTitle: "string",
      scriptureReference: "string",
      scriptureParaphrase: "string",
      reflectionThought: "string",
      prayer: "string",
      todayAim: "string",
      updatedJourneyArc: {
        purpose: "string",
        journeyPurpose: "string",
        currentStage: "string",
        todayAim: "string",
        nextMovement: "string",
        tone: "string",
        practicalActionDirection: "string",
        recentDayTitles: ["string"],
        lastFollowThroughInterpretation: "string",
        specificContextSignals: ["string"]
      }
    },
    repairNotes: repairNotes ?? null,
    instructions: [
      "Build the devotional around the selected Scripture first, then the user's journey purpose. If the verse would still make sense for dozens of unrelated prompts, choose a more specific passage.",
      "Before returning JSON, privately check that all fields serve the same point, the reflection reads as one complete thought, the reflection uses simpler wording where possible, the reflection contains no practical assignment or meta framing, the title is not generic, the prayer names concrete realities from the journey, and the arc fields are all present.",
      "If the prompt is broad, infer a concrete first lesson without pretending to know private details.",
      "For marriage/spouse journeys, Scripture/reflection/prayer should connect directly to sacrificial love, humility, patience, listening, service, or tenderness.",
      "For anxiety/peace journeys, avoid vague calm language; connect prayer, trust, and one steady thought from Scripture.",
      "Avoid repeating recent titles, verses, aims, or action patterns too soon.",
      "If follow-through was partial/no, simplify the next movement without shame. If yes, increase specificity slightly."
    ],
    context: {
      languageCode: language.code,
      localeIdentifier: language.localeIdentifier,
      ...compactContext(input)
    }
  }, null, 2);

  return { system, user };
}

export function buildActionLayerPrompt(input: JourneyPackageRequest, core: DevotionalCore, repairNotes?: string): { system: string; user: string } {
  const language = targetLanguage(input);
  const system = [
    "You write the practical Tend action layer from an approved devotional core.",
    "Respond with strict JSON only, no markdown and no prose outside JSON.",
    `Write smallStepQuestion, suggestedSteps, and completionSuggestion entirely in ${language.label} (${language.code}).`,
    "The question and every suggested step must flow from todayAim, the devotional core's central point, and the journey context.",
    "No unrelated generic steps. If the journey is about being a better husband, do not suggest praying for a friend or generic check-ins.",
    "For specific contexts, include at least two real-world actions, one lower-friction option when helpful, and one prayer/spiritual option only if it directly relates.",
    "Suggested steps should be short, practical, safe, and not expensive or manipulative.",
    "Question should be one simple practical question, usually under 14 words."
  ].join(" ");

  const user = JSON.stringify({
    outputSchema: {
      smallStepQuestion: "string",
      suggestedSteps: ["string", "string", "string", "string"],
      completionSuggestion: {
        shouldPrompt: "boolean",
        reason: "string",
        confidence: "number 0..1"
      }
    },
    repairNotes: repairNotes ?? null,
    examples: {
      marriageValid: ["Write a kind note", "Ask one caring question", "Do one helpful chore", "Pray for your wife"],
      marriageInvalid: ["Pray for one friend", "Schedule one check-in", "Pray over one next step"]
    },
    devotionalCore: core,
    context: {
      languageCode: language.code,
      localeIdentifier: language.localeIdentifier,
      ...compactContext(input)
    }
  }, null, 2);

  return { system, user };
}
