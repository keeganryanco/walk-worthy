import test from "node:test";
import assert from "node:assert/strict";

import {
  normalizeActionLayerFromObject,
  normalizeDevotionalCoreFromObject
} from "./validate.ts";
import { actionModel, devotionalModel, repairModel } from "./modelRouting.ts";
import { DAILY_JOURNEY_PACKAGE_QUALITY_VERSION } from "./types.ts";
import type { JourneyPackageRequest } from "./types.ts";

const husbandRequest: JourneyPackageRequest = {
  profile: {
    prayerFocus: "help me be a better husband",
    growthGoal: "love my wife with patience and humility"
  },
  journey: {
    id: "journey-husband",
    title: "Better Husband",
    category: "Marriage",
    themeKey: "community"
  },
  journeyArc: {
    purpose: "learn Christlike love in marriage",
    journeyPurpose: "learn Christlike love in marriage",
    currentStage: "beginning with sacrificial attention",
    todayAim: "practice concrete love toward your wife",
    nextMovement: "Move from vague intention into attentive love at home.",
    tone: "grounded, specific, biblically anchored",
    practicalActionDirection: "Use spouse-specific actions.",
    recentDayTitles: [],
    lastFollowThroughInterpretation: "",
    specificContextSignals: ["husband", "wife", "marriage"]
  },
  recentJourneySignals: ["help me be a better husband"],
  languageCode: "en",
  localeIdentifier: "en-US"
};

const validArc = {
  purpose: "learn Christlike love in marriage",
  journeyPurpose: "learn Christlike love in marriage",
  currentStage: "beginning with sacrificial attention",
  todayAim: "practice concrete love toward your wife",
  nextMovement: "Move from vague intention into attentive love at home.",
  tone: "grounded, specific, biblically anchored",
  practicalActionDirection: "Use spouse-specific actions.",
  recentDayTitles: ["Learning Sacrificial Love"],
  lastFollowThroughInterpretation: "",
  specificContextSignals: ["husband", "wife", "marriage"]
};

const validCoreSource = {
  dailyTitle: "Learning Sacrificial Love",
  scriptureReference: "John 15:12",
  scriptureParaphrase: "Jesus commands His disciples to love one another as He has loved them.",
  reflectionThought:
    "Jesus defines love by His own self-giving pattern. His command reveals that love is not only affection but a chosen posture of service and patience. For a husband, this turns marriage into a daily place where Christlike love becomes visible. Sacrificial love grows in the ordinary places where attention, humility, and tenderness become steady.",
  prayer:
    "Jesus, I bring my marriage and my role as a husband to You today. Teach me to love my wife with patience, humility, and attention. Show me where selfishness or passivity has shaped my habits.",
  todayAim: "practice concrete love toward your wife",
  updatedJourneyArc: validArc
};

test("model routing defaults use gpt-5.5 core and gpt-5.1 action", () => {
  const original = { ...process.env };
  delete process.env.OPENAI_DEVOTIONAL_MODEL;
  delete process.env.OPENAI_ESCALATION_MODEL;
  delete process.env.OPENAI_PRIMARY_MODEL;
  delete process.env.OPENAI_ACTION_MODEL;
  delete process.env.OPENAI_UTILITY_MODEL;
  delete process.env.OPENAI_REPAIR_MODEL;

  try {
    assert.equal(devotionalModel(), "gpt-5.5");
    assert.equal(actionModel(), "gpt-5.1");
    assert.equal(repairModel(), "gpt-5.5");
  } finally {
    process.env = original;
  }
});

test("current package quality version invalidates stale cached output", () => {
  assert.equal(DAILY_JOURNEY_PACKAGE_QUALITY_VERSION, 4);
});

test("valid spouse-specific devotional core passes", () => {
  assert.ok(normalizeDevotionalCoreFromObject(validCoreSource, husbandRequest));
});

test("reflection with practical commands fails validation", () => {
  const result = normalizeDevotionalCoreFromObject(
    {
      ...validCoreSource,
      reflectionThought:
        "Jesus defines love by His own self-giving pattern. His command reveals that love is not only affection but a chosen posture of service and patience. Ask your wife one caring question today. Write a kind note before the day ends."
    },
    husbandRequest
  );

  assert.equal(result, null);
});

test("example husband reflection with disguised action framing fails validation", () => {
  const result = normalizeDevotionalCoreFromObject(
    {
      ...validCoreSource,
      reflectionThought:
        "Growth as a husband often begins with small, quiet choices that no one else sees. Notice one area where the heart feels stirred to love more intentionally today. Let that awareness lead to one simple act of kindness or listening. Trust that God values even the smallest step of love."
    },
    husbandRequest
  );

  assert.equal(result, null);
});

test("vague Christianese prayer fails validation", () => {
  const result = normalizeDevotionalCoreFromObject(
    {
      ...validCoreSource,
      prayer:
        "Lord, I ask You to help our home reflect your grace more and more. Give me deeper reliance and a higher purpose. Help me grow closer to you."
    },
    husbandRequest
  );

  assert.equal(result, null);
});

test("meta-devotional reflection framing fails validation", () => {
  const result = normalizeDevotionalCoreFromObject(
    {
      ...validCoreSource,
      reflectionThought:
        "Jesus defines love by His own self-giving pattern. His command reveals that love is not only affection but a chosen posture of service and patience. For a husband, this turns marriage into a daily place where Christlike love becomes visible. Today's lesson is learning to let love become attentive, humble, and steady."
    },
    husbandRequest
  );

  assert.equal(result, null);
});

test("generic daily title fails validation", () => {
  const result = normalizeDevotionalCoreFromObject(
    {
      ...validCoreSource,
      dailyTitle: "Growing in Faith"
    },
    husbandRequest
  );

  assert.equal(result, null);
});

test("todayAim and updatedJourneyArc are required", () => {
  assert.equal(
    normalizeDevotionalCoreFromObject({ ...validCoreSource, todayAim: "" }, husbandRequest),
    null
  );
  const { updatedJourneyArc: _updatedJourneyArc, ...withoutArc } = validCoreSource;
  assert.equal(normalizeDevotionalCoreFromObject(withoutArc, husbandRequest), null);
});

test("unrelated husband or marriage steps fail validation", () => {
  const core = normalizeDevotionalCoreFromObject(validCoreSource, husbandRequest);
  assert.ok(core);

  const result = normalizeActionLayerFromObject(
    {
      smallStepQuestion: "What is one simple way to show love today?",
      suggestedSteps: ["Pray for one friend", "Schedule one check-in", "Pray over one next step"],
      completionSuggestion: { shouldPrompt: false, reason: "", confidence: 0 }
    },
    husbandRequest,
    core
  );

  assert.equal(result, null);
});

test("relevant spouse and marriage steps pass validation", () => {
  const core = normalizeDevotionalCoreFromObject(validCoreSource, husbandRequest);
  assert.ok(core);

  const result = normalizeActionLayerFromObject(
    {
      smallStepQuestion: "What is one simple way to show love today?",
      suggestedSteps: ["Write a kind note", "Ask one caring question", "Do one helpful chore", "Pray for your wife"],
      completionSuggestion: { shouldPrompt: false, reason: "", confidence: 0 }
    },
    husbandRequest,
    core
  );

  assert.deepEqual(result?.suggestedSteps, [
    "Write a kind note",
    "Ask one caring question",
    "Do one helpful chore",
    "Pray for your wife"
  ]);
});
