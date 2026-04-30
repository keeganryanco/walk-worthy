import test from "node:test";
import assert from "node:assert/strict";

import {
  normalizeActionLayerFromObject,
  normalizeDevotionalCoreFromObject
} from "./validate.ts";
import { normalizeReference } from "./scripture.ts";
import { fallbackPackage } from "./fallback.ts";
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
  centralConcern: "learning to love my wife with patience and humility",
  biblicalTheme: "Christlike sacrificial love in marriage",
  devotionalPoint: "A husband learns love by letting Christ's self-giving love shape ordinary moments in marriage.",
  scriptureFitReason: "John 15:12 directly grounds marriage love in the way Jesus loves His people.",
  dailyTitle: "Learning Sacrificial Love",
  scriptureReference: "John 15:12",
  scriptureParaphrase: "Jesus commands His disciples to love one another as He has loved them.",
  reflectionThought:
    "Jesus shows that love for God is tied to love for the person close beside you. His command makes love more than a feeling because it becomes patient, humble, and ready to serve. For a husband, this turns marriage into a daily place where Christlike love becomes real. Sacrificial love grows in ordinary moments of care, listening, and humility.",
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
  assert.equal(DAILY_JOURNEY_PACKAGE_QUALITY_VERSION, 6);
});

test("valid spouse-specific devotional core passes", () => {
  assert.ok(normalizeDevotionalCoreFromObject(validCoreSource, husbandRequest));
});

test("marriage context rejects broad love command scripture by itself", () => {
  const result = normalizeDevotionalCoreFromObject(
    {
      ...validCoreSource,
      scriptureReference: "Matthew 22:37-39",
      scriptureParaphrase:
        "Jesus says the greatest command is to love God with all the heart, soul, and mind, and the second is to love your neighbor as yourself.",
      reflectionThought:
        "Jesus shows that love for God is tied to love for the person close beside you. In marriage, love becomes real when it is patient, humble, and willing to serve. A husband is growing in the right direction when his daily choices look less selfish and more like the way Christ loves. Sacrificial love is learned in ordinary moments of care, listening, and humility."
    },
    husbandRequest
  );

  assert.equal(result, null);
});

test("multi-reference scripture passes when one passage directly fits marriage", () => {
  const result = normalizeDevotionalCoreFromObject(
    {
      ...validCoreSource,
      scriptureReference: "Matthew 22:37-39; Ephesians 5:25",
      scriptureParaphrase:
        "Jesus says the greatest command is to love God and to love your neighbor as yourself. Paul tells husbands to love their wives as Christ loved the church and gave Himself for her."
    },
    husbandRequest
  );

  assert.equal(result?.scriptureReference, "Matthew 22:37-39; Ephesians 5:25");
});

test("scripture references may normalize to a semicolon-separated set", () => {
  assert.equal(normalizeReference("John 15:12; Mark 10:45"), "John 15:12; Mark 10:45");
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

test("overly dense abstract reflection language fails validation", () => {
  const result = normalizeDevotionalCoreFromObject(
    {
      ...validCoreSource,
      reflectionThought:
        "Jesus joins love for God with love for the person placed near enough to receive it. In marriage, that love becomes more than sentiment when it is patient, humble, and attentive. A husband grows when his habits are shaped less by passivity or defensiveness and more by Christlike service. Sacrificial love is learned in the ordinary places where tenderness and humility become visible."
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

const futureImpactRequest: JourneyPackageRequest = {
  profile: {
    prayerFocus: "anxiety about my future and doing great things and having great impact on the world",
    growthGoal: "hold ambition with peace, wisdom, humility, and service"
  },
  journey: {
    id: "journey-future-impact",
    title: "Future Impact",
    category: "Calling",
    themeKey: "wisdom"
  },
  journeyArc: {
    purpose: "bring anxiety about the future and impact to God",
    journeyPurpose: "bring anxiety about the future and impact to God",
    currentStage: "naming ambition and fear honestly",
    todayAim: "hold ambition with humility and wisdom",
    nextMovement: "Continue discerning calling without pressure to prove yourself.",
    tone: "grounded, specific, biblically anchored",
    practicalActionDirection: "Use actions tied to anxiety, ambition, work, service, and wisdom.",
    recentDayTitles: [],
    lastFollowThroughInterpretation: "",
    specificContextSignals: ["future", "anxiety", "impact", "ambition", "calling"]
  },
  recentJourneySignals: ["future", "impact", "ambition", "anxiety"],
  languageCode: "en",
  localeIdentifier: "en-US"
};

const futureImpactArc = {
  purpose: "bring anxiety about the future and impact to God",
  journeyPurpose: "bring anxiety about the future and impact to God",
  currentStage: "naming ambition and fear honestly",
  todayAim: "hold ambition with humility and wisdom",
  nextMovement: "Continue discerning calling without pressure to prove yourself.",
  tone: "grounded, specific, biblically anchored",
  practicalActionDirection: "Use actions tied to anxiety, ambition, work, service, and wisdom.",
  recentDayTitles: ["Holding Ambition Loosely"],
  lastFollowThroughInterpretation: "",
  specificContextSignals: ["future", "anxiety", "impact", "ambition", "calling"]
};

test("Romans 12:10 cannot keep unrelated Philippians-style paraphrase", () => {
  const result = normalizeDevotionalCoreFromObject(
    {
      ...validCoreSource,
      scriptureReference: "Romans 12:10",
      scriptureParaphrase: "Bring your requests to God with trust, and take one faithful step today."
    },
    husbandRequest
  );

  assert.equal(result, null);

  const communityResult = normalizeDevotionalCoreFromObject(
    {
      ...validCoreSource,
      centralConcern: "learning to honor one another in love",
      biblicalTheme: "devoted love and honor",
      devotionalPoint: "Christian love becomes concrete when honor replaces self-importance.",
      scriptureFitReason: "Romans 12:10 names devoted love and honor directly.",
      scriptureReference: "Romans 12:10",
      scriptureParaphrase: "Bring your requests to God with trust, and take one faithful step today.",
      reflectionThought:
        "Paul describes love as devotion that chooses honor over self-importance. That kind of love is not vague warmth because it makes another person's good matter deeply. In close relationships, honor can soften the pride that turns every need into a contest. Love becomes steadier when devotion and humility belong together.",
      prayer:
        "Lord, I bring You my relationships and my desire to love well. Teach me to honor people without needing to be first. Show me where pride has made me guarded.",
      updatedJourneyArc: { ...validArc, specificContextSignals: ["relationships", "honor", "love"] }
    },
    {
      ...husbandRequest,
      profile: { prayerFocus: "honor a friend in love", growthGoal: "practice humble love" },
      journey: { id: "journey-love", title: "Learning Honor", category: "Friendship", themeKey: "community" },
      recentJourneySignals: ["friend", "honor", "love"]
    }
  );

  assert.equal(
    communityResult?.scriptureParaphrase,
    "Be devoted to one another in love, and honor one another above yourselves."
  );
});

test("scripture paraphrase cannot contain action-step language after normalization", () => {
  const result = normalizeDevotionalCoreFromObject(
    {
      ...validCoreSource,
      scriptureParaphrase: "Take one faithful step today and move forward."
    },
    husbandRequest
  );

  assert.ok(result);
  assert.doesNotMatch(result.scriptureParaphrase, /faithful step|move forward|concrete step/i);
});

test("reflection with small-step devotional action language fails validation", () => {
  const result = normalizeDevotionalCoreFromObject(
    {
      ...validCoreSource,
      reflectionThought:
        "Jesus defines love by His own self-giving pattern. His command reveals that love is not only affection but a chosen posture of service and patience. A small step can reveal which part of life needs attention and care. Real growth is shaped by faithfulness, not pressure."
    },
    husbandRequest
  );

  assert.equal(result, null);
});

test("prayer with concrete-step action language fails validation", () => {
  const result = normalizeDevotionalCoreFromObject(
    {
      ...validCoreSource,
      prayer:
        "Lord, I place this journey in Your hands today. Give me wisdom for one concrete step. Help me follow through with steady faith. Keep my heart close to You as I act."
    },
    husbandRequest
  );

  assert.equal(result, null);
});

test("future impact anxiety core accepts relevant scripture and concrete language", () => {
  const result = normalizeDevotionalCoreFromObject(
    {
      centralConcern: "anxiety about the future and wanting meaningful impact",
      biblicalTheme: "calling shaped by service instead of self-pressure",
      devotionalPoint: "God can reshape ambition so impact becomes service rather than proof of worth.",
      scriptureFitReason: "Matthew 5:16 connects visible good works with giving glory to the Father.",
      dailyTitle: "Holding Ambition Loosely",
      scriptureReference: "Matthew 5:16",
      scriptureParaphrase:
        "Let your light shine before others, so they may see your good works and give glory to your Father in heaven.",
      reflectionThought:
        "Jesus teaches that visible good can point people back to the Father. This keeps impact from becoming a stage for proving personal worth. Anxiety about the future often grows when calling is measured by greatness before service. Ambition becomes healthier when it is held with humility, wisdom, and love for the people who may be helped.",
      prayer:
        "Lord, I bring You my fear about the future and my desire to matter. Teach me to want impact that serves people and honors You. Keep ambition from becoming pressure to prove myself. Give me wisdom, humility, and peace as I grow.",
      todayAim: "hold ambition with humility and wisdom",
      updatedJourneyArc: futureImpactArc
    },
    futureImpactRequest
  );

  assert.ok(result);
  assert.match(
    result.scriptureReference,
    /^(Matthew 5:16|Ephesians 2:10|Colossians 3:17|Philippians 4:6-7|James 1:5)$/
  );
  assert.match(result.reflectionThought, /future|impact|calling|ambition/i);
  assert.match(result.prayer, /fear|ambition|future|humility|wisdom|service|impact/i);
});

test("future impact anxiety action layer stays practical and related", () => {
  const core = normalizeDevotionalCoreFromObject(
    {
      centralConcern: "anxiety about the future and wanting meaningful impact",
      biblicalTheme: "calling shaped by service instead of self-pressure",
      devotionalPoint: "God can reshape ambition so impact becomes service rather than proof of worth.",
      scriptureFitReason: "James 1:5 fits a request for wisdom about the future.",
      dailyTitle: "Asking For Wisdom",
      scriptureReference: "James 1:5",
      scriptureParaphrase: "If anyone lacks wisdom, they should ask God, who gives generously without finding fault.",
      reflectionThought:
        "James treats wisdom as something God gives generously to people who lack it. That matters when the future feels large and hard to read. A desire for impact can become anxious when every decision feels like proof of calling. God meets ambition with wisdom that is generous, humble, and steady.",
      prayer:
        "Lord, I bring You my fear about the future and my desire to matter. Give me wisdom that is humble and clear. Keep ambition from becoming pressure to prove myself.",
      todayAim: "ask God for wisdom about ambition and impact",
      updatedJourneyArc: futureImpactArc
    },
    futureImpactRequest
  );
  assert.ok(core);

  const action = normalizeActionLayerFromObject(
    {
      smallStepQuestion: "What is one wise way to face your future today?",
      suggestedSteps: ["Name one fear clearly", "Pray over one ambition", "Do one focused work block", "Encourage one person"],
      completionSuggestion: { shouldPrompt: false, reason: "", confidence: 0 }
    },
    futureImpactRequest,
    core
  );

  assert.deepEqual(action?.suggestedSteps, [
    "Name one fear clearly",
    "Pray over one ambition",
    "Do one focused work block",
    "Encourage one person"
  ]);
});

test("fallback output never pairs a random reference with generic action paraphrase", () => {
  const output = fallbackPackage(futureImpactRequest);

  assert.doesNotMatch(output.scriptureParaphrase, /take one faithful step|one concrete step|small step/i);
  assert.doesNotMatch(output.reflectionThought, /this area of prayer|A small step can reveal|move forward today/i);
  assert.doesNotMatch(output.prayer, /one concrete step|as I act|small, faithful step/i);
  assert.match(`${output.reflectionThought} ${output.prayer}`, /future|impact|ambition|anxiety|calling|fear|wisdom|service/i);
  assert.deepEqual(output.suggestedSteps, [
    "Name one fear clearly",
    "Pray over one ambition",
    "Do one focused work block",
    "Encourage one person"
  ]);
});
