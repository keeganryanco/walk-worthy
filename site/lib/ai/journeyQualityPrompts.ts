import { APPROVED_SCRIPTURE_REFERENCES } from "./scripture";
import type { DevotionalCore, DevotionalPlan, JourneyPackageRequest } from "./types";

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

export function buildDevotionalPlanPrompt(input: JourneyPackageRequest, repairNotes?: string): { system: string; user: string } {
  const language = targetLanguage(input);
  const system = [
    "You are the planning editor for Tend, a personal Christian devotional journey app.",
    "Respond with strict JSON only, no markdown and no prose outside JSON.",
    "Your job is not to write the devotional. Your job is to choose one coherent topic/angle/message for today's devotional.",
    "Think in this order: user's concern, broad journey direction, today's specific angle, biblical theme, one devotional point, Scripture candidates, title seed, prayer focus, action direction.",
    "Do not choose a title first. The titleSeed must come from the devotionalPoint and Scripture fit.",
    "The todayAngle must be narrow enough that a 4-6 sentence reflection can stay on it without drifting into adjacent topics.",
    "The devotionalPoint must answer what the titleSeed means and why Scripture speaks to it.",
    "For example, if the titleSeed is Holding Ambition Loosely, the devotionalPoint should explain what it means to be ambitious while trusting God, not drift into generic influence or pressure.",
    "For ordinary-life prompts such as a driver's test, breakup, school exam, business anxiety, or family conflict, infer the deeper spiritual concern without losing the concrete situation.",
    "candidateScriptureReferences must contain 1-3 references from the approved library only:",
    APPROVED_SCRIPTURE_REFERENCES.join(", "),
    `Write all fields in ${language.label} (${language.code}) except candidateScriptureReferences, which must use canonical English references from the approved library.`
  ].join(" ");

  const user = JSON.stringify({
    outputSchema: {
      centralConcern: "specific concern inferred from the user's request",
      journeyDirection: "broad direction of the ongoing journey",
      todayAngle: "one narrow angle/message for today's devotional",
      biblicalTheme: "specific biblical theme",
      devotionalPoint: "one sentence point the title, reflection, prayer, and action should all serve",
      scriptureFitReason: "why the Scripture candidates fit this exact point",
      titleSeed: "short story-like title seed from the point and Scripture",
      prayerFocus: "what the prayer should ask God for, concretely",
      actionDirection: "what kind of practical Tend action naturally follows, without writing chips yet",
      candidateScriptureReferences: ["string"]
    },
    repairNotes: repairNotes ?? null,
    context: {
      languageCode: language.code,
      localeIdentifier: language.localeIdentifier,
      ...compactContext(input)
    }
  }, null, 2);

  return { system, user };
}

export function buildDevotionalCorePrompt(
  input: JourneyPackageRequest,
  plan?: DevotionalPlan,
  repairNotes?: string
): { system: string; user: string } {
  const language = targetLanguage(input);
  const reflectionVoiceRule =
    language.code === "ja" || language.code === "ko"
      ? "For reflectionThought, second-person teaching voice is preferred, but first-person voice is allowed when natural in this language."
      : "Reflection must not use first-person pronouns (I/me/my/we/us/our).";
  const system = [
    "You are writing the devotional core for Tend, a personal Christian devotional journey app.",
    "Respond with strict JSON only, no markdown and no prose outside JSON.",
    "If repairNotes are present, treat them as private validation diagnostics. Fix the output silently; never mention the error, validation, retry, schema, or repair process in any returned field.",
    "Write like a careful devotional editor, not like generic Christian marketing copy.",
    "The day must feel like one intentional lesson in an ongoing journey, not a disconnected topical thought.",
    plan
      ? "Execute the approved devotional plan exactly; do not change its centralConcern, todayAngle, devotionalPoint, Scripture candidates, or title direction unless repairNotes explicitly require it."
      : "Privately decide the one clear devotional point this package is communicating before writing any field.",
    "The title, Scripture choice, reflection, prayer, todayAim, and journey arc must all flow from that same point without sounding formulaic.",
    "Generate in this order: choose/confirm the daily topic angle, choose Scripture, write reflection from the topic and Scripture, settle the dailyTitle from that reflection, then write prayer and arc fields.",
    "Use plain, easy-to-follow language in the reflection. A thoughtful child should be able to follow the main point, while an adult should still feel respected.",
    "Do not try to sound literary, academic, or impressive. Prefer common words when they communicate the same idea.",
    "One rich word is fine when it matters; do not stack abstract words like sentiment, passivity, defensiveness, posture, implication, or attentiveness.",
    "Do not claim guaranteed healing, money, relationship outcomes, or divine promises beyond Scripture.",
    "Avoid denominational controversy and keep the tone grounded and sincere.",
    `Write centralConcern, biblicalTheme, devotionalPoint, scriptureFitReason, dailyTitle, scriptureParaphrase, reflectionThought, prayer, todayAim, and updatedJourneyArc fields in ${language.label} (${language.code}).`,
    "Choose Scripture before writing the reflection. The reflection's main point must clearly arise from what the selected Scripture says, not merely sit beside a broadly related verse.",
    "Use one scripture reference by default. Use 2-3 references only when the combined passages truly deepen the same point; if using multiple references, separate them with semicolons.",
    "You must choose scriptureReference only from this approved scripture library; do not use any other reference for this rollout:",
    APPROVED_SCRIPTURE_REFERENCES.join(", "),
    plan
      ? `Choose scriptureReference from the plan's candidateScriptureReferences only: ${plan.candidateScriptureReferences.join(", ")}.`
      : "Choose the reference that best serves today's specific devotional point, not just the broad category.",
    "The backend will verify and replace scriptureParaphrase from the approved library, but your paraphrase must still be near-quote style: close to the selected verse or verses, faithful to each cited reference, no translation label.",
    "If using multiple references, paraphrase each passage in the same order without blending them into a fake single verse.",
    "Do not turn Scripture into application language. Scripture paraphrase must not say faithful step, concrete step, next step, move forward today, or similar action phrases unless the approved verse itself says that exact idea.",
    "Do not use broad love, peace, or trust verses when a more specific passage would carry the user's actual situation better.",
    "For marriage/spouse journeys, prefer passages about sacrificial love, patient love, humility, service, tenderness, and honoring a spouse, such as Ephesians 5:25, Colossians 3:19, 1 Peter 3:7, John 15:12, 1 Corinthians 13:4-7, Mark 10:45, or Galatians 5:13.",
    "For unusual prompts, map the request to its biblical theme first: grief, wisdom, stewardship, diligence, ambition, humility, identity, forgiveness, peace, endurance, or love.",
    "Reflection must be 4-6 complete sentences. It teaches/interprets Scripture in relation to the journey as one coherent thought with a beginning, middle, and end.",
    "Use this reflection shape without making it obvious: sentence 1 anchors in the selected Scripture; sentence 2 explains what the Scripture means in simple terms; sentence 3 connects that truth to the user's journey; sentence 4 or 5 closes the thought with a plain, grounded sentence.",
    "After sentence 2, do not switch to a neighboring topic. Use the remaining sentences to deepen the dailyTitle and devotionalPoint.",
    "The reflection should answer the promise implied by the title. If the title is about holding ambition loosely, the reflection should explain ambition held with trust, humility, and service.",
    "Do not use meta-devotional framing such as 'Today's lesson', 'the lesson is', 'the takeaway', 'this devotional', 'this reflection', or 'in conclusion'.",
    "Reflection is not the action step. Prayer is not the action step. Practical action belongs only in the Tend action layer, not in scriptureParaphrase, reflectionThought, or prayer.",
    "Do not use faithful step, concrete step, small step, next step, move from prayer into action, what can you do, guide my action, or as I act in scriptureParaphrase, reflectionThought, or prayer.",
    "Do not tell the user to send, buy, schedule, text, call, ask, apologize, plan, do, take, write, choose, or finish anything in reflection.",
    "Rare reflective language is allowed only when internal and interpretive, such as 'Notice how...' or 'Consider how...'; do not use 'Notice one area...' or 'Let that awareness lead...'.",
    reflectionVoiceRule,
    "Prayer must be exactly 3-4 complete sentences, strictly first-person, plain, concrete, and Christian.",
    "Ban empty Christianese filler such as 'reflect your grace more and more', 'deeper reliance', 'divine care', 'higher purpose', 'profound sense', 'inner stability', or similar phrases unless immediately made concrete.",
    "Daily title must be short, concrete, story-like, and sequential, for example: Learning Sacrificial Love, Choosing Peace Today, Practicing Prayer When Distracted.",
    "Reject generic titles like Growing in Faith, Trusting God More, Daily Peace, A Step Toward Love, or Today's Faithful Step."
  ].join(" ");

  const user = JSON.stringify({
    outputSchema: {
      centralConcern: "specific concern inferred from the user's request, not a generic category",
      biblicalTheme: "specific biblical theme connecting the concern to Scripture",
      devotionalPoint: "one clear point the reflection, prayer, and action layer should serve",
      scriptureFitReason: "why the chosen reference fits this exact concern",
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
      plan
        ? "Use devotionalPlan as the locked topic/angle/message. The output may polish wording, but it should not broaden or drift away from the plan."
        : "Build the devotional around the selected Scripture first, then the user's journey purpose. If the verse would still make sense for dozens of unrelated prompts, choose a more specific passage.",
      "Before returning JSON, privately check that all fields serve the same point, the reflection reads as one complete thought, the title accurately names the reflection, the reflection uses simpler wording where possible, the reflection contains no practical assignment or meta framing, the prayer names concrete realities from the journey, and the arc fields are all present.",
      "If the prompt is broad, infer a concrete first lesson without pretending to know private details.",
      "For marriage/spouse journeys, Scripture/reflection/prayer should connect directly to sacrificial love, humility, patience, listening, service, or tenderness.",
      "For anxiety/peace journeys, avoid vague calm language; connect prayer, trust, and one steady thought from Scripture.",
      "Avoid repeating recent titles, verses, aims, or action patterns too soon.",
      "If follow-through was partial/no, simplify the next movement without shame. If yes, increase specificity slightly."
    ],
    context: {
      languageCode: language.code,
      localeIdentifier: language.localeIdentifier,
      devotionalPlan: plan ?? null,
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
    "This is the only layer where practical action language belongs; do not rewrite the Scripture, reflection, or prayer.",
    "No unrelated generic steps. If the journey is about being a better husband, do not suggest praying for a friend or generic check-ins.",
    "Do not repeat the same action with tiny wording changes. Avoid near-duplicates like 'Pray through this worry', 'Pray through one worry', and 'Pray through this specific worry' in the same list.",
    "Use varied action types: at most one prayer-focused chip, plus concrete options like preparation, communication, rest, work, service, naming a fear, or asking for help when they fit the devotional.",
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
