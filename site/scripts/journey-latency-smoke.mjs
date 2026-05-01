const baseURL = (process.env.TEND_SMOKE_BASE_URL || "http://localhost:3000").replace(/\/$/, "");
const sharedSecret = process.env.TEND_APP_SHARED_SECRET || "";

const prompts = [
  "my girlfriend of 5 years just broke up with me and I'm heartbroken",
  "I'm anxious for the ACT test at school next week",
  "anxiety about my future and growing my business"
];

async function postJSON(path, body) {
  const startedAt = performance.now();
  const response = await fetch(`${baseURL}${path}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(sharedSecret ? { "x-tend-app-key": sharedSecret } : {})
    },
    body: JSON.stringify(body)
  });
  const elapsedMS = Math.round(performance.now() - startedAt);
  const text = await response.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }
  if (!response.ok) {
    throw new Error(`${path} failed with ${response.status} after ${elapsedMS}ms: ${text}`);
  }
  return { json, elapsedMS };
}

async function smokePrompt(prompt, index) {
  const seedBody = {
    name: "Friend",
    prayerIntentText: prompt,
    reminderWindow: "Morning",
    languageCode: "en",
    localeIdentifier: "en-US",
    telemetry: { distinctID: `latency_smoke_${index}`, platform: "script" }
  };

  const seed = await postJSON("/api/v1/journey-seed", seedBody);
  const seedPayload = seed.json.seed;
  const packageBase = {
    profile: {
      prayerFocus: prompt,
      growthGoal: seedPayload.growthFocus,
      reminderWindow: "Morning"
    },
    journey: {
      id: `latency-smoke-${index}`,
      title: seedPayload.journeyTitle,
      category: seedPayload.journeyCategory,
      themeKey: seedPayload.themeKey
    },
    journeyArc: seedPayload.journeyArc,
    recentJourneySignals: [prompt, seedPayload.growthFocus],
    languageCode: "en",
    localeIdentifier: "en-US",
    telemetry: { distinctID: `latency_smoke_${index}`, platform: "script" }
  };

  const core = await postJSON("/api/v1/journey-core", packageBase);
  const action = await postJSON("/api/v1/journey-action", {
    ...packageBase,
    core: core.json.core
  });

  return {
    prompt,
    seedMS: seed.elapsedMS,
    coreMS: core.elapsedMS,
    actionMS: action.elapsedMS,
    totalMS: seed.elapsedMS + core.elapsedMS + action.elapsedMS,
    title: core.json.core.dailyTitle,
    reference: core.json.core.scriptureReference,
    model: `${seed.json.meta?.model ?? "unknown"} + ${core.json.meta?.model ?? "unknown"} + ${action.json.meta?.model ?? "unknown"}`
  };
}

const results = [];
for (const [index, prompt] of prompts.entries()) {
  console.log(`\nPrompt ${index + 1}: ${prompt}`);
  const result = await smokePrompt(prompt, index + 1);
  results.push(result);
  console.log(result);
}

const totalMS = results.reduce((sum, result) => sum + result.totalMS, 0);
console.log(`\nAverage staged total: ${Math.round(totalMS / results.length)}ms`);
