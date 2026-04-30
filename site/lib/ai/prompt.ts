import { DevotionalCore, JourneyPackageRequest } from "./types";
import { APPROVED_SCRIPTURE_REFERENCES } from "./scripture";

function targetLanguage(input: JourneyPackageRequest): { code: "en" | "es" | "pt" | "de" | "ja" | "ko"; label: string; localeIdentifier: string } {
  const languageCode = (input.languageCode ?? "").trim().toLowerCase();
  const localeIdentifier = (input.localeIdentifier ?? "").trim() || "en-US";
  if (languageCode.startsWith("es") || localeIdentifier.toLowerCase().startsWith("es")) {
    return { code: "es", label: "Spanish", localeIdentifier };
  }
  if (languageCode.startsWith("pt") || localeIdentifier.toLowerCase().startsWith("pt")) {
    return { code: "pt", label: "Portuguese (Brazil)", localeIdentifier };
  }
  if (languageCode.startsWith("de") || localeIdentifier.toLowerCase().startsWith("de")) {
    return { code: "de", label: "German", localeIdentifier };
  }
  if (languageCode.startsWith("ja") || localeIdentifier.toLowerCase().startsWith("ja")) {
    return { code: "ja", label: "Japanese", localeIdentifier };
  }
  if (languageCode.startsWith("ko") || localeIdentifier.toLowerCase().startsWith("ko")) {
    return { code: "ko", label: "Korean", localeIdentifier };
  }
  return { code: "en", label: "English", localeIdentifier };
}

export function buildPrompt(input: JourneyPackageRequest): { system: string; user: string } {
  const language = targetLanguage(input);
  const followThroughContext =
    (input as JourneyPackageRequest & { followThroughContext?: Record<string, unknown> }).followThroughContext ?? {};

  const system = [
    "You generate one daily Christian devotional journey package for an iOS app.",
    "Respond with strict JSON only, no markdown, no prose outside JSON.",
    "Do not claim supernatural guarantees, healing guarantees, or financial guarantees.",
    "Do not include inflammatory denominational commentary, sectarian attacks, or arguments about which Christian tradition is superior.",
    "Keep religious language respectful, invitational, and non-coercive. Do not shame, threaten, or pressure the user spiritually.",
    "Choose Scripture before writing the reflection. The reflection's main point must clearly arise from what the selected Scripture says, not merely sit beside a broadly related verse.",
    "Use one scripture reference by default. Use 2-3 references only when the combined passages truly deepen the same point; if using multiple references, separate them with semicolons.",
    "Choose scriptureReference only from this approved scripture library:",
    APPROVED_SCRIPTURE_REFERENCES.join(", "),
    "Provide scripture paraphrase only; do not mention NIV/ESV/NLT/KJV or any translation label and do not quote copyrighted verse text verbatim.",
    "Do not turn Scripture into application language. scriptureParaphrase, reflectionThought, and prayer must not use faithful step, concrete step, small step, next step, move from prayer into action, what can you do, guide my action, or as I act.",
    "Keep tone grounded and sincere.",
    "Privately decide the one clear devotional point this package is communicating before writing any field.",
    "The title, Scripture choice, reflection, prayer, action question, and suggested steps should all flow from that same point without sounding formulaic.",
    "Use plain, easy-to-follow language in reflectionThought. A thoughtful child should be able to follow the main point, while an adult should still feel respected.",
    "Do not try to sound literary, academic, or impressive. Prefer common words when they communicate the same idea.",
    `Write reflectionThought, scriptureParaphrase, prayer, smallStepQuestion, and suggestedSteps entirely in ${language.label} (${language.code}).`,
    "Do not include translation notes, bilingual output, or language labels.",
    "This must feel like the next day in an ongoing devotional journey, not a standalone topical thought."
  ].join(" ");

  const recent = (input.recentEntries ?? [])
    .slice(0, 8)
    .map((entry) => ({
      actionStep: entry.actionStep ?? "",
      userReflection: entry.userReflection ?? "",
      scriptureReference: entry.scriptureReference ?? "",
      completed: Boolean(entry.completedAt),
      followThroughStatus: entry.followThroughStatus ?? ""
    }));

  const usedScriptureReferences = Array.from(
    new Set(
      (input.usedScriptureReferences ?? [])
        .map((value) => value.trim())
        .filter(Boolean)
    )
  ).slice(0, 140);

  const user = JSON.stringify(
    {
      outputSchema: {
        centralConcern: "specific concern inferred from the user's request, not a generic category",
        biblicalTheme: "specific biblical theme connecting the concern to Scripture",
        devotionalPoint: "one clear point the reflection, prayer, and action layer should serve",
        scriptureFitReason: "why the chosen reference fits this exact concern",
        dailyTitle: "string",
        reflectionThought: "string",
        scriptureReference: "string",
        scriptureParaphrase: "string",
        prayer: "string",
        todayAim: "string",
        smallStepQuestion: "string",
        suggestedSteps: ["string", "string", "string"],
        completionSuggestion: {
          shouldPrompt: "boolean",
          reason: "string",
          confidence: "number 0..1"
        },
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
      instructions: [
        "Make the reflection concrete, specific to this journey, and connected to the current journeyArc.nextMovement.",
        "reflectionThought must be exactly 4-5 complete sentences.",
        "reflectionThought should read naturally as one coherent thought with a beginning, middle, and end.",
        "Use simpler wording where possible; do not stack abstract words like sentiment, passivity, defensiveness, posture, implication, or attentiveness.",
        "Do not use meta-devotional framing such as 'Today's lesson', 'the lesson is', 'the takeaway', 'this devotional', 'this reflection', or 'in conclusion'.",
        "Practical action language belongs only in smallStepQuestion and suggestedSteps, not in scriptureParaphrase, reflectionThought, or prayer.",
        "You may use phrasing like 'Reflect on ...' when it fits, but do not force a fixed opening phrase.",
        "Do not always begin reflectionThought with 'Take a moment to reflect on'.",
        "Do not use first-person pronouns (I/me/my/we/us/our) in reflectionThought.",
        "Avoid abstract filler like higher purpose, profound sense, deeper reliance, inner stability, or divine care unless the user context specifically asks for it.",
        "Scripture paraphrase should be near-quote style: very close to the selected verse’s wording, with only small wording changes that connect to today's devotional focus.",
        "Keep scriptureParaphrase to 1-3 concise sentences and stay faithful to the cited verse or verses.",
        "If using multiple references, paraphrase each passage in the same order without blending them into a fake single verse.",
        "For marriage/spouse journeys, prefer passages about sacrificial love, patient love, humility, service, tenderness, and honoring a spouse, such as Ephesians 5:25, Colossians 3:19, 1 Peter 3:7, John 15:12, 1 Corinthians 13:4-7, Mark 10:45, or Galatians 5:13.",
        "ScriptureReference MUST NOT repeat any reference listed in context.usedScriptureReferences.",
        "Prayer must be exactly 3-4 complete sentences and strictly first-person voice (I/me/my/we/us/our).",
        "Never refer to the user in third person (for example: 'the user', 'they', or by name).",
        "smallStepQuestion must be one simple question, usually under 14 words, that asks what the user can do today to partner with the thing they are praying about.",
        "Suggested step chips must be complete, actionable phrases (no fragments), practical, and short (target 3-8 words each).",
        "If user context is specific enough, suggestedSteps should become specific real-life actions, not vague spiritual actions.",
        "Include a mix: one concrete practical action, one lower-friction action, and one prayer/spiritual action when appropriate.",
        "For relationship or marriage contexts, specific actions like buying flowers, writing a note, apologizing, asking a direct question, or planning a short check-in are allowed when context supports them.",
        "Avoid unsafe, manipulative, expensive, shaming, or conflict-escalating suggestions.",
        "Never end a suggested chip with dangling words like 'to', 'for', or 'with'.",
        "Advance the journey: use memory, recent entries, and follow-through context to move the focus forward instead of repeating yesterday's angle.",
        "If followThroughContext.previousFollowThroughStatus is partial or no, lower the next-step difficulty and use gentler wording.",
        "If followThroughContext.previousFollowThroughStatus is yes, keep the tone encouraging and increase specificity slightly.",
        "For partial/no follow-through, suggested chips should feel easier and smaller than a normal day.",
        "Only set completionSuggestion.shouldPrompt=true when completionCount is at least 7 and journey signals indicate meaningful progress."
      ],
      context: {
        dateISO: input.dateISO ?? new Date().toISOString(),
        languageCode: language.code,
        localeIdentifier: language.localeIdentifier,
        journey: input.journey,
        profile: input.profile,
        memory: input.memory ?? {},
        journeyArc: input.journeyArc ?? null,
        followThroughContext,
        usedScriptureReferences,
        recentEntries: recent,
        cycleCount: input.cycleCount ?? 0,
        completionCount: input.completionCount ?? 0,
        recentJourneySignals: input.recentJourneySignals ?? []
      }
    },
    null,
    2
  );

  return { system, user };
}

export function buildDevotionalCorePrompt(input: JourneyPackageRequest): { system: string; user: string } {
  const language = targetLanguage(input);
  const recent = (input.recentEntries ?? [])
    .slice(0, 8)
    .map((entry) => ({
      actionStep: entry.actionStep ?? "",
      userReflection: entry.userReflection ?? "",
      scriptureReference: entry.scriptureReference ?? "",
      completed: Boolean(entry.completedAt),
      followThroughStatus: entry.followThroughStatus ?? ""
    }));
  const usedScriptureReferences = Array.from(
    new Set((input.usedScriptureReferences ?? []).map((value) => value.trim()).filter(Boolean))
  ).slice(0, 140);

  const system = [
    "You are the devotional authoring layer for Tend, a personal Christian devotional journey app.",
    "Return strict JSON only.",
    "Use the highest-quality, intentional reasoning: this should feel authored, sequential, biblical, and worth the user's time.",
    "Privately decide the one clear devotional point this package is communicating before writing any field.",
    "The title, Scripture choice, reflection, prayer, todayAim, and journey arc should all flow from that same point without sounding formulaic.",
    "Use plain, easy-to-follow language in the reflection. A thoughtful child should be able to follow the main point, while an adult should still feel respected.",
    "Do not try to sound literary, academic, or impressive. Prefer common words when they communicate the same idea.",
    "Create only the devotional core: title, scripture, reflection, prayer, todayAim, and updatedJourneyArc.",
    "Do not write the action question or suggested actions here.",
    "The reflection is teaching and interpretation, not assignment. It must not tell the user to send, buy, schedule, text, call, write, ask, apologize, plan, do, take, clean, cook, bring, serve, finish, or start a practical action.",
    "Prayer is not the action step. Practical action belongs only in the Tend action layer, not in scriptureParaphrase, reflectionThought, or prayer.",
    "Do not use faithful step, concrete step, small step, next step, move from prayer into action, what can you do, guide my action, or as I act in scriptureParaphrase, reflectionThought, or prayer.",
    "Rare reflective directives like Notice or Consider are allowed only when they point inward to understanding, not outward to a task.",
    "Reflection must be exactly 4-5 complete sentences, concrete, biblically anchored, not first-person, and shaped as one coherent thought with a natural close.",
    "Use simpler wording where possible; do not stack abstract words like sentiment, passivity, defensiveness, posture, implication, or attentiveness.",
    "Do not use meta-devotional framing such as 'Today's lesson', 'the lesson is', 'the takeaway', 'this devotional', 'this reflection', or 'in conclusion'.",
    "Prayer must be exactly 3-4 complete sentences, first-person only, plain, concrete Christian language.",
    "Ban empty Christianese: do not use phrases like reflect your grace more and more, deeper reliance, divine care, higher purpose, profound sense, inner stability, or walk in victory unless immediately made concrete.",
    "Choose Scripture before writing the reflection. The reflection's main point must clearly arise from what the selected Scripture says, not merely sit beside a broadly related verse.",
    "Use one scripture reference by default. Use 2-3 references only when the combined passages truly deepen the same point; if using multiple references, separate them with semicolons.",
    "scriptureReference must come only from this approved scripture library:",
    APPROVED_SCRIPTURE_REFERENCES.join(", "),
    "Scripture paraphrase must be near-quote style, anchored to the cited verse or verses, with no translation label.",
    "If using multiple references, paraphrase each passage in the same order without blending them into a fake single verse.",
    "For marriage/spouse journeys, prefer passages about sacrificial love, patient love, humility, service, tenderness, and honoring a spouse, such as Ephesians 5:25, Colossians 3:19, 1 Peter 3:7, John 15:12, 1 Corinthians 13:4-7, Mark 10:45, or Galatians 5:13.",
    "Daily title must be short, concrete, and story-like, making this feel like the next day in an arc.",
    `Write all user-facing text in ${language.label} (${language.code}).`,
    "Do not include translation notes, bilingual output, or markdown."
  ].join(" ");

  const user = JSON.stringify(
    {
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
      context: {
        dateISO: input.dateISO ?? new Date().toISOString(),
        languageCode: language.code,
        localeIdentifier: language.localeIdentifier,
        journey: input.journey,
        profile: input.profile,
        memory: input.memory ?? {},
        journeyArc: input.journeyArc ?? null,
        followThroughContext: input.followThroughContext ?? {},
        usedScriptureReferences,
        recentEntries: recent,
        cycleCount: input.cycleCount ?? 0,
        completionCount: input.completionCount ?? 0,
        recentJourneySignals: input.recentJourneySignals ?? []
      }
    },
    null,
    2
  );

  return { system, user };
}

export function buildActionLayerPrompt(input: JourneyPackageRequest, core: DevotionalCore): { system: string; user: string } {
  const language = targetLanguage(input);
  const system = [
    "You are the practical action layer for Tend.",
    "Return strict JSON only.",
    "Use the devotional core to create one simple action question and four suggested steps.",
    "Every suggested step must match the journey context and today's aim.",
    "Question must be one practical question, usually under 14 words, flowing from todayAim.",
    "For specific contexts, include at least two specific real-world actions.",
    "Include one lower-friction option when helpful.",
    "Include one prayer/spiritual option only if it directly relates to the specific journey.",
    "For a husband, wife, spouse, or marriage journey, valid actions include writing a kind note, asking one caring question, doing one helpful chore, buying flowers, listening without distraction, apologizing specifically, or praying for the wife/spouse.",
    "For a husband, wife, spouse, or marriage journey, invalid actions include praying for one friend, a generic check-in, or praying over one next step.",
    "Avoid unsafe, manipulative, expensive, shaming, or conflict-escalating suggestions.",
    "Suggested steps must be complete short phrases and never dangling fragments.",
    `Write all user-facing text in ${language.label} (${language.code}).`,
    "Do not include translation notes, bilingual output, or markdown."
  ].join(" ");

  const recentActions = (input.recentEntries ?? [])
    .slice(0, 8)
    .map((entry) => entry.actionStep ?? "")
    .filter(Boolean);

  const user = JSON.stringify(
    {
      outputSchema: {
        smallStepQuestion: "string",
        suggestedSteps: ["string", "string", "string", "string"],
        completionSuggestion: {
          shouldPrompt: "boolean",
          reason: "string",
          confidence: "number 0..1"
        }
      },
      devotionalCore: core,
      context: {
        languageCode: language.code,
        localeIdentifier: language.localeIdentifier,
        journey: input.journey,
        profile: input.profile,
        journeyArc: input.journeyArc ?? null,
        followThroughContext: input.followThroughContext ?? {},
        recentActions,
        recentJourneySignals: input.recentJourneySignals ?? [],
        completionCount: input.completionCount ?? 0
      }
    },
    null,
    2
  );

  return { system, user };
}
