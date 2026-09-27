import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

import {
  BetaAccount,
  BetaDailyQuota,
  authenticateBetaDeviceSession,
  handleRequest,
  normalizeDailyQuotaStateForDay,
} from "../src/index.js";

const gatewayUrl = "https://gateway.example.test/v1/ai/complete";
const imageGatewayUrl = "https://gateway.example.test/v1/ai/image";
const speechGatewayUrl = "https://gateway.example.test/v1/ai/speech";
const betaActivationUrl = "https://gateway.example.test/v1/beta/activate";
const videoEditPlanGatewayUrl = "https://gateway.example.test/v1/ai/video/edit-plan";
const videoTranscriptionGatewayUrl = "https://gateway.example.test/v1/ai/video/transcribe";
const betaToken = "revocable-tester-token";
const openAiSecret = "openai-test-secret-must-not-leak";
const openRouterSecret = "openrouter-test-secret-must-not-leak";
const quotaDay = "2026-09-08";
const quotaNow = Date.parse("2026-09-08T12:00:00.000Z");
const betaInviteCode = "closed-beta-invite-code";
const sessionSigningKey = "unit-test-session-signing-key-at-least-32-chars";

function createQuotaWithStoredState(storedState) {
  let state = structuredClone(storedState);
  const storage = {
    async transaction(callback) {
      return callback({
        async get(key) {
          assert.equal(key, "current-day");
          return state;
        },
        async put(key, nextState) {
          assert.equal(key, "current-day");
          state = nextState;
        },
      });
    },
  };

  return {
    quota: new BetaDailyQuota({ storage }, {}),
    storedState: () => state,
  };
}

function createBetaAccountsNamespace() {
  const states = new Map();
  const env = { OVEXIQ_SESSION_SIGNING_KEY: sessionSigningKey };
  return {
    getByName(name) {
      let state = states.get(name);
      const storage = {
        async transaction(callback) {
          return callback({
            async get(key) {
              assert.equal(key, "beta-account");
              return state;
            },
            async put(key, nextState) {
              assert.equal(key, "beta-account");
              state = structuredClone(nextState);
              states.set(name, state);
            },
          });
        },
      };
      return new BetaAccount({ storage }, env);
    },
    states,
  };
}

function createEnv({
  rateLimitSuccess = true,
  rateLimiter = null,
  imageRateLimitSuccess = true,
  includeOpenRouter = true,
} = {}) {
  let quotaCalls = 0;
  const env = {
    OPENAI_API_KEY: openAiSecret,
    OPENAI_MODEL: "openai-test-model",
    OVEXIQ_BETA_TOKENS: JSON.stringify({ "tester-one": betaToken }),
    OVEXIQ_BETA_INVITES: JSON.stringify({ "invite-one": betaInviteCode }),
    OVEXIQ_SESSION_SIGNING_KEY: sessionSigningKey,
    AI_RATE_LIMITER: rateLimiter ?? {
      async limit({ key }) {
        assert.equal(key, "beta:tester-one");
        return { success: rateLimitSuccess };
      },
    },
    IMAGE_RATE_LIMITER: {
      async limit({ key }) {
        assert.equal(key, "beta:tester-one");
        return { success: imageRateLimitSuccess };
      },
    },
    BETA_DAILY_QUOTA: {
      getByName(name) {
        assert.equal(name, "ovexiq-beta-daily-quota");
        return {
          async consume() {
            quotaCalls += 1;
            return { allowed: true };
          },
        };
      },
    },
  };

  if (includeOpenRouter) {
    env.OPENROUTER_API_KEY = openRouterSecret;
    env.OPENROUTER_MODEL = "mistralai/mistral-small-2603";
  }

  env.BETA_ACCOUNTS = createBetaAccountsNamespace();
  env.quotaCalls = () => quotaCalls;

  return env;
}

function createCountingRateLimiter(limit) {
  let attempts = 0;

  return {
    async limit({ key }) {
      assert.equal(key, "beta:tester-one");
      attempts += 1;
      return { success: attempts <= limit };
    },
    attempts: () => attempts,
  };
}

function createRequest(body, token = betaToken) {
  const headers = { "Content-Type": "application/json" };
  if (token !== null) {
    headers["X-Ovexiq-Beta-Token"] = token;
  }

  return new Request(gatewayUrl, {
    method: "POST",
    headers,
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

function createImageRequest(
  body,
  token = betaToken,
  { method = "POST", contentType = "application/json" } = {},
) {
  const headers = {};
  if (contentType !== null) {
    headers["Content-Type"] = contentType;
  }
  if (token !== null) {
    headers["X-Ovexiq-Beta-Token"] = token;
  }

  return new Request(imageGatewayUrl, {
    method,
    headers,
    ...(method === "POST"
      ? { body: typeof body === "string" ? body : JSON.stringify(body) }
      : {}),
  });
}

function createVideoEditPlanRequest(
  body,
  token = betaToken,
  { method = "POST", contentType = "application/json" } = {},
) {
  const headers = {};
  if (contentType !== null) {
    headers["Content-Type"] = contentType;
  }
  if (token !== null) {
    headers["X-Ovexiq-Beta-Token"] = token;
  }

  return new Request(videoEditPlanGatewayUrl, {
    method,
    headers,
    ...(method === "POST"
      ? { body: typeof body === "string" ? body : JSON.stringify(body) }
      : {}),
  });
}

function createVideoTranscriptionRequest(
  {
    clipId = "clip-one",
    bytes = new Uint8Array([1, 2, 3]),
    mimeType = "audio/mp4",
  } = {},
  token = betaToken,
  { method = "POST", contentType = null } = {},
) {
  const headers = {};
  if (token !== null) {
    headers["X-Ovexiq-Beta-Token"] = token;
  }
  if (contentType !== null) {
    headers["Content-Type"] = contentType;
  }
  if (method !== "POST" || contentType !== null) {
    return new Request(videoTranscriptionGatewayUrl, { method, headers });
  }
  const form = new FormData();
  form.set("clipId", clipId);
  form.set("audio", new Blob([bytes], { type: mimeType }), "clip.m4a");
  return new Request(videoTranscriptionGatewayUrl, { method, headers, body: form });
}

function validBody() {
  return {
    messages: [
      { role: "system", content: "Be concise." },
      { role: "user", content: "Research Kaspa." },
      { role: "assistant", content: "Prior accepted result." },
      { role: "user", content: "Summarize it." },
    ],
    temperature: 0.4,
    maxTokens: 800,
    metadata: { missionId: "mission-1", taskId: "task-2" },
  };
}

function createSpeechRequest(
  body,
  token = betaToken,
  { method = "POST", contentType = "application/json" } = {},
) {
  const headers = {};
  if (contentType !== null) {
    headers["Content-Type"] = contentType;
  }
  if (token !== null) {
    headers["X-Ovexiq-Beta-Token"] = token;
  }
  return new Request(speechGatewayUrl, {
    method,
    headers,
    ...(method === "POST"
      ? { body: typeof body === "string" ? body : JSON.stringify(body) }
      : {}),
  });
}

function burmeseBody({ maxTokens = 800 } = {}) {
  return {
    ...validBody(),
    maxTokens,
    response_language: "my",
  };
}

function createBetaActivationRequest(
  body,
  token = betaToken,
  { method = "POST", contentType = "application/json" } = {},
) {
  const headers = {};
  if (contentType !== null) {
    headers["Content-Type"] = contentType;
  }
  if (token !== null) {
    headers["X-Ovexiq-Beta-Token"] = token;
  }
  return new Request(betaActivationUrl, {
    method,
    headers,
    ...(method === "POST"
      ? { body: typeof body === "string" ? body : JSON.stringify(body) }
      : {}),
  });
}

let protectedRequestActivationCount = 0;

async function activateDeviceSession(
  env,
  activationId = `protected-installation-${++protectedRequestActivationCount}-abcdefghijklmnop`,
) {
  const activationResponse = await handleRequest(
    createBetaActivationRequest({
      inviteCode: betaInviteCode,
      activationId,
    }),
    env,
    globalThis.fetch,
  );
  assert.equal(activationResponse.status, 201);
  return activationResponse.json();
}

function withDeviceSession(request, deviceSession, accountId) {
  const headers = new Headers(request.headers);
  headers.set("X-Ovexiq-Device-Session", deviceSession);
  if (accountId !== undefined) {
    headers.set("X-Ovexiq-Account-Id", accountId);
  }
  return new Request(request, { headers });
}

async function handleAuthorizedRequest(request, env, fetchProvider) {
  return handleRequest(
    withDeviceSession(request, (await activateDeviceSession(env)).deviceSession),
    env,
    fetchProvider,
  );
}

function openAiSuccess(text = "Normalized result") {
  return new Response(
    JSON.stringify({
      id: "provider-request-id",
      model: "openai-test-model",
      output: [{ content: [{ type: "output_text", text }] }],
      usage: { input_tokens: 42, output_tokens: 17 },
    }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
}

function openRouterSuccess(text = "Fallback result") {
  return new Response(
    JSON.stringify({
      choices: [{ message: { content: text } }],
      usage: { prompt_tokens: 31, completion_tokens: 13 },
    }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
}

function openAiImageSuccess(base64 = "safe-image-base64") {
  return new Response(
    JSON.stringify({
      created: 123,
      data: [{ b64_json: base64 }],
    }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
}

function openAiSpeechSuccess(bytes = new Uint8Array([1, 2, 3])) {
  return new Response(bytes, {
    status: 200,
    headers: { "Content-Type": "audio/mpeg" },
  });
}

function validVideoEditPlanRequest() {
  return {
    instruction: "Make a 30 second TikTok.",
    clips: [
      {
        clipId: "clip-one",
        durationMs: 15_000,
        width: 1920,
        height: 1080,
        orientation: "landscape",
        hasAudio: true,
        fileSizeBytes: 2_000,
        frameRate: 30,
        contentAnalysis: {
          analysisVersion: "local_signals_v1",
          speechPresent: true,
          transcriptSegments: [
            { startMs: 0, endMs: 1_000, text: "A welcome to the lake." },
          ],
          sceneSegments: [
            { startMs: 0, endMs: 1_000, label: "outdoors" },
          ],
          audioActivity: [{ startMs: 0, endMs: 1_000 }],
        },
      },
      {
        clipId: "clip-two",
        durationMs: 15_000,
        width: 1080,
        height: 1920,
        orientation: "portrait",
        hasAudio: true,
        fileSizeBytes: 2_000,
        contentAnalysis: { analysisVersion: "local_empty_v1" },
      },
    ],
    output: { targetDurationMs: 30_000, verticalSocialVideo: true },
  };
}

function validSingleVideoEditPlanRequest() {
  const request = validVideoEditPlanRequest();
  request.clips = [{
    ...request.clips[0],
    durationMs: 90_000,
  }];
  return request;
}

function openAiVideoEditPlanSuccess(plan = {
  targetDurationMs: 30_000,
  segments: [
    {
      clipId: "clip-one",
      keep: true,
      order: 0,
      trimStartMs: null,
      trimEndMs: null,
    },
    {
      clipId: "clip-two",
      keep: true,
      order: 1,
      trimStartMs: null,
      trimEndMs: null,
    },
  ],
}) {
  return openAiSuccess(JSON.stringify(plan));
}

function openAiTranscriptionSuccess({
  language = "my",
  segments = [{ start: 0, end: 3.2, text: "မင်္ဂလာပါ" }],
} = {}) {
  return new Response(
    JSON.stringify({ language, segments }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
}

test("rejects missing and invalid beta tokens", async () => {
  const providerFetch = async () => {
    throw new Error("provider must not be called");
  };

  const missing = await handleRequest(
    createRequest(validBody(), null),
    createEnv(),
    providerFetch,
  );
  const invalid = await handleRequest(
    createRequest(validBody(), "invalid-token"),
    createEnv(),
    providerFetch,
  );

  assert.equal(missing.status, 401);
  assert.equal(invalid.status, 401);
});
test("requires an active device session before budgeted routes use quota or providers", async () => {
  const routes = [
    {
      name: "complete",
      request: () => createRequest(validBody()),
      success: () => openAiSuccess(),
    },
    {
      name: "image",
      request: () => createImageRequest({ prompt: "Buddha" }),
      success: () => openAiImageSuccess(),
    },
    {
      name: "speech",
      request: () => createSpeechRequest({ text: "မင်္ဂလာပါ" }),
      success: () => openAiSpeechSuccess(),
    },
  ];

  for (const route of routes) {
    const missingEnv = createEnv();
    let missingProviderCalls = 0;
    const missing = await handleRequest(
      route.request(),
      missingEnv,
      async () => {
        missingProviderCalls += 1;
        return route.success();
      },
    );
    assert.equal(missing.status, 401, `${route.name} missing session`);
    assert.equal((await missing.json()).error.code, "unauthorized");
    assert.equal(missingProviderCalls, 0);
    assert.equal(missingEnv.quotaCalls(), 0);

    const activeEnv = createEnv();
    const activation = await activateDeviceSession(activeEnv);
    let activeProviderCalls = 0;
    const active = await handleRequest(
      withDeviceSession(
        route.request(),
        activation.deviceSession,
        "acct_client_claim_must_be_ignored",
      ),
      activeEnv,
      async () => {
        activeProviderCalls += 1;
        return route.success();
      },
    );
    assert.equal(active.status, 200, `${route.name} active session`);
    assert.equal(activeProviderCalls, 1);

    const revokedEnv = createEnv();
    const revokedActivation = await activateDeviceSession(revokedEnv);
    const account = revokedEnv.BETA_ACCOUNTS.getByName(
      "ovexiq-beta-account:invite-one",
    );
    assert.equal(
      (await account.revokeSession(revokedActivation.deviceSession.split(".")[2]))
        .revoked,
      true,
    );
    let revokedProviderCalls = 0;
    const revoked = await handleRequest(
      withDeviceSession(route.request(), revokedActivation.deviceSession),
      revokedEnv,
      async () => {
        revokedProviderCalls += 1;
        return route.success();
      },
    );
    assert.equal(revoked.status, 401, `${route.name} revoked session`);
    assert.equal((await revoked.json()).error.code, "unauthorized");
    assert.equal(revokedProviderCalls, 0);
    assert.equal(revokedEnv.quotaCalls(), 0);
  }
});

test("rejects malformed and oversized payloads", async () => {
  const providerFetch = async () => {
    throw new Error("provider must not be called");
  };

  const malformed = await handleAuthorizedRequest(
    createRequest("{not-json"),
    createEnv(),
    providerFetch,
  );
  const oversized = await handleAuthorizedRequest(
    createRequest({ messages: [{ role: "user", content: "x".repeat(12_001) }] }),
    createEnv(),
    providerFetch,
  );

  assert.equal(malformed.status, 400);
  assert.equal(oversized.status, 413);
});

test("uses OpenAI as the primary provider without calling OpenRouter when it succeeds", async () => {
  let upstreamBody;
  let calls = 0;
  const providerFetch = async (url, options) => {
    calls += 1;
    assert.equal(url, "https://api.openai.com/v1/responses");
    assert.equal(options.headers.Authorization, `Bearer ${openAiSecret}`);
    upstreamBody = JSON.parse(options.body);
    return openAiSuccess();
  };

  const response = await handleAuthorizedRequest(createRequest(validBody()), createEnv(), providerFetch);
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(calls, 1);
  assert.deepEqual(upstreamBody.input, validBody().messages);
  assert.equal(upstreamBody.store, false);
  assert.equal("temperature" in upstreamBody, false);
  assert.equal(upstreamBody.max_output_tokens, 800);
  assert.deepEqual(payload, {
    content: "Normalized result",
    model: "openai-test-model",
    requestId: "provider-request-id",
    usage: { promptTokens: 42, completionTokens: 17 },
  });
});

test("accepts the mixed Burmese and English KG lesson-plan chat contract", async () => {
  const lessonPlanRequest = {
    messages: [
      { role: "system", content: "Give a useful answer first." },
      {
        role: "user",
        content: "Help me write Transportation lesson plan for KG kids - KG ကလေးတွေအတွက် lesson plan တစ်ခုရေးပေး",
      },
    ],
    temperature: 0.7,
  };
  let calls = 0;
  const response = await handleAuthorizedRequest(
    createRequest(lessonPlanRequest),
    createEnv(),
    async (url, options) => {
      calls += 1;
      assert.equal(url, "https://api.openai.com/v1/responses");
      const body = JSON.parse(options.body);
      assert.deepEqual(body.input, lessonPlanRequest.messages);
      return openAiSuccess("Transportation lesson plan");
    },
  );

  assert.equal(response.status, 200);
  assert.equal(calls, 1);
  assert.deepEqual(await response.json(), {
    content: "Transportation lesson plan",
    model: "openai-test-model",
    requestId: "provider-request-id",
    usage: { promptTokens: 42, completionTokens: 17 },
  });
});

test("routes Burmese requests to the approved strong model", async () => {
  let calls = 0;
  let upstreamBody;
  const providerFetch = async (url, options) => {
    calls += 1;
    assert.equal(url, "https://openrouter.ai/api/v1/chat/completions");
    upstreamBody = JSON.parse(options.body);
    return openRouterSuccess("Burmese result");
  };

  const response = await handleAuthorizedRequest(
    createRequest(burmeseBody()),
    createEnv(),
    providerFetch,
  );

  assert.equal(response.status, 200);
  assert.equal(calls, 1);
  assert.equal(upstreamBody.model, "openai/gpt-6-astra");
  assert.equal(upstreamBody.max_tokens, 800);
  assert.deepEqual(upstreamBody.messages, burmeseBody().messages);
  assert.equal("temperature" in upstreamBody, false);
  assert.equal("reasoning" in upstreamBody, false);
});

test("caps Burmese output tokens at the server-side maximum", async () => {
  let upstreamBody;
  const providerFetch = async (url, options) => {
    assert.equal(url, "https://openrouter.ai/api/v1/chat/completions");
    upstreamBody = JSON.parse(options.body);
    return openRouterSuccess("Burmese result");
  };

  const response = await handleAuthorizedRequest(
    createRequest(burmeseBody({ maxTokens: 4096 })),
    createEnv(),
    providerFetch,
  );

  assert.equal(response.status, 200);
  assert.equal(upstreamBody.max_tokens, 1800);
});

test("does not downgrade Burmese requests when the strong model fails", async () => {
  let calls = 0;
  const response = await handleAuthorizedRequest(
    createRequest(burmeseBody()),
    createEnv(),
    async (url) => {
      calls += 1;
      assert.equal(url, "https://openrouter.ai/api/v1/chat/completions");
      return new Response("", { status: 503 });
    },
  );

  assert.equal(response.status, 502);
  assert.equal(calls, 1);
});

test("English response language retains standard model routing", async () => {
  const requestBody = validBody();
  requestBody.response_language = "en";
  let calls = 0;
  let upstreamBody;
  const response = await handleAuthorizedRequest(
    createRequest(requestBody),
    createEnv(),
    async (url, options) => {
      calls += 1;
      assert.equal(url, "https://api.openai.com/v1/responses");
      upstreamBody = JSON.parse(options.body);
      return openAiSuccess();
    },
  );

  assert.equal(response.status, 200);
  assert.equal(calls, 1);
  assert.equal(upstreamBody.model, "openai-test-model");
});

test("rejects invalid response language before provider invocation", async () => {
  const requestBody = validBody();
  requestBody.response_language = "ko";
  let calls = 0;

  const response = await handleAuthorizedRequest(
    createRequest(requestBody),
    createEnv(),
    async () => {
      calls += 1;
      return openAiSuccess();
    },
  );

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), {
    error: {
      code: "invalid_response_language",
      message: "response_language must be my, en, or auto.",
    },
  });
  assert.equal(calls, 0);
});

test("safe route telemetry excludes request content and credentials", async () => {
  const telemetry = [];
  const originalInfo = console.info;
  console.info = (entry) => telemetry.push(entry);

  try {
    const response = await handleAuthorizedRequest(
      createRequest(burmeseBody()),
      createEnv(),
      async () => openRouterSuccess("Burmese result"),
    );

    assert.equal(response.status, 200);
  } finally {
    console.info = originalInfo;
  }

  assert.equal(telemetry.length, 1);
  const event = JSON.parse(telemetry[0]);
  assert.equal(event.event, "ovexiq_ai_route");
  assert.equal(event.route_class, "burmese_strong");
  assert.equal(event.response_language, "my");
  assert.equal(event.provider_transport, "openrouter_chat_completions");
  assert.equal(event.provider_outcome, "success");
  assert.equal(event.model, "openai/gpt-6-astra");
  assert.equal(event.fallback_attempted, false);
  assert.equal(event.failure_category, null);
  assert.match(event.request_id, /^[0-9a-f-]{36}$/i);
  assert.equal(JSON.stringify(event).includes("Research Kaspa"), false);
  assert.equal(JSON.stringify(event).includes(openAiSecret), false);
  assert.equal(JSON.stringify(event).includes(betaToken), false);
});

test("maps Burmese upstream failures to safe distinct telemetry without a fallback", async () => {
  const cases = [
    { status: 400, category: "provider_rejected_4xx", statusCategory: "4xx" },
    { status: 429, category: "provider_rate_limited", statusCategory: "429" },
    { status: 503, category: "provider_upstream_5xx", statusCategory: "5xx" },
  ];

  for (const { status, category, statusCategory } of cases) {
    const telemetry = [];
    const originalInfo = console.info;
    console.info = (entry) => telemetry.push(entry);
    try {
      const response = await handleAuthorizedRequest(
        createRequest(burmeseBody()),
        createEnv(),
        async () => new Response("", { status }),
      );

      assert.equal(response.status, 502);
      assert.match(response.headers.get("X-Ovexiq-Request-Id"), /^[0-9a-f-]{36}$/i);
    } finally {
      console.info = originalInfo;
    }

    const event = JSON.parse(telemetry[0]);
    assert.equal(event.failure_category, category);
    assert.equal(event.upstream_http_status, status);
    assert.equal(event.upstream_status_category, statusCategory);
    assert.equal(event.fallback_attempted, false);
    assert.equal(event.timeout, false);
  }
});

test("maps malformed, empty, and timeout Burmese provider results safely", async () => {
  const cases = [
    {
      name: "malformed",
      fetch: async () => new Response("not json", { status: 200 }),
      category: "invalid_provider_response",
      timedOut: false,
    },
    {
      name: "empty",
      fetch: async () => new Response(JSON.stringify({ choices: [] }), { status: 200 }),
      category: "empty_provider_response",
      timedOut: false,
    },
    {
      name: "timeout",
      fetch: async () => {
        const error = new Error("timeout");
        error.name = "AbortError";
        throw error;
      },
      category: "provider_timeout",
      timedOut: true,
    },
  ];

  for (const testCase of cases) {
    const telemetry = [];
    const originalInfo = console.info;
    console.info = (entry) => telemetry.push(entry);
    try {
      const response = await handleAuthorizedRequest(
        createRequest(burmeseBody()),
        createEnv(),
        testCase.fetch,
      );
      assert.equal(response.status, testCase.name === "timeout" ? 504 : 502);
    } finally {
      console.info = originalInfo;
    }

    const event = JSON.parse(telemetry[0]);
    assert.equal(event.failure_category, testCase.category);
    assert.equal(event.timeout, testCase.timedOut);
    assert.equal(event.fallback_attempted, false);
  }
});

test("uses the extended timeout only for the Burmese strong route", async () => {
  const observedTimeouts = [];
  const originalSetTimeout = globalThis.setTimeout;
  globalThis.setTimeout = (callback, delay, ...args) => {
    observedTimeouts.push(delay);
    return originalSetTimeout(callback, delay, ...args);
  };

  try {
    const burmeseResponse = await handleAuthorizedRequest(
      createRequest(burmeseBody()),
      createEnv(),
      async () => openRouterSuccess("Burmese result"),
    );
    assert.equal(burmeseResponse.status, 200);
    assert.ok(observedTimeouts.includes(75_000));
    observedTimeouts.length = 0;

    const englishResponse = await handleAuthorizedRequest(
      createRequest(validBody()),
      createEnv(),
      async () => openAiSuccess("English result"),
    );
    assert.equal(englishResponse.status, 200);
  } finally {
    globalThis.setTimeout = originalSetTimeout;
  }

  assert.ok(observedTimeouts.includes(30_000));
  assert.equal(observedTimeouts.includes(75_000), false);
});

test("falls back after each allowed transient primary failure", async () => {
  const transientFailures = [
    {
      name: "timeout",
      fetch: async () => {
        const error = new Error("timeout");
        error.name = "AbortError";
        throw error;
      },
    },
    { name: "network error", fetch: async () => { throw new Error("network unavailable"); } },
    { name: "rate limit", fetch: async () => new Response("", { status: 429 }) },
    { name: "server error", fetch: async () => new Response("", { status: 503 }) },
    { name: "invalid success body", fetch: async () => new Response("not json", { status: 200 }) },
    {
      name: "empty success body",
      fetch: async () => new Response(JSON.stringify({ output: [] }), { status: 200 }),
    },
  ];

  for (const transientFailure of transientFailures) {
    let calls = 0;
    const providerFetch = async (url) => {
      calls += 1;
      if (url === "https://api.openai.com/v1/responses") {
        return transientFailure.fetch();
      }

      assert.equal(url, "https://openrouter.ai/api/v1/chat/completions");
      return openRouterSuccess(transientFailure.name);
    };

  const response = await handleAuthorizedRequest(createRequest(validBody()), createEnv(), providerFetch);
    const payload = await response.json();

    assert.equal(response.status, 200, transientFailure.name);
    assert.equal(payload.content, transientFailure.name);
    assert.equal(calls, 2, transientFailure.name);
  }
});

test("maps the neutral request to OpenRouter and keeps its credential backend-only", async () => {
  let openRouterRequest;
  const providerFetch = async (url, options) => {
    if (url === "https://api.openai.com/v1/responses") {
      return new Response("", { status: 503 });
    }

    openRouterRequest = { url, options, body: JSON.parse(options.body) };
    return openRouterSuccess();
  };

  const response = await handleAuthorizedRequest(createRequest(validBody()), createEnv(), providerFetch);
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(
    openRouterRequest.url,
    "https://openrouter.ai/api/v1/chat/completions",
  );
  assert.equal(openRouterRequest.url.includes(openRouterSecret), false);
  assert.equal(openRouterRequest.options.headers.Authorization, `Bearer ${openRouterSecret}`);
  assert.equal("x-goog-api-key" in openRouterRequest.options.headers, false);
  assert.deepEqual(openRouterRequest.body, {
    model: "mistralai/mistral-small-2603",
    messages: validBody().messages,
    max_tokens: 800,
    temperature: 0.4,
  });
  assert.deepEqual(payload, {
    content: "Fallback result",
    usage: { promptTokens: 31, completionTokens: 13 },
  });
  assert.equal(JSON.stringify(payload).toLowerCase().includes("openrouter"), false);
  assert.equal(JSON.stringify(payload).includes(openRouterSecret), false);
});

test("omits OpenRouter temperature when the validated request does not include it", async () => {
  let openRouterBody;
  const requestBody = validBody();
  delete requestBody.temperature;

  const providerFetch = async (url, options) => {
    if (url === "https://api.openai.com/v1/responses") {
      return new Response("", { status: 503 });
    }

    openRouterBody = JSON.parse(options.body);
    return openRouterSuccess();
  };

  const response = await handleAuthorizedRequest(createRequest(requestBody), createEnv(), providerFetch);

  assert.equal(response.status, 200);
  assert.equal("temperature" in openRouterBody, false);
});

test("does not fall back when OpenRouter is not configured", async () => {
  let calls = 0;
  const providerFetch = async () => {
    calls += 1;
    return new Response("", { status: 503 });
  };

  const response = await handleAuthorizedRequest(
    createRequest(validBody()),
    createEnv({ includeOpenRouter: false }),
    providerFetch,
  );
  const body = await response.text();

  assert.equal(response.status, 502);
  assert.equal(calls, 1);
  assert.equal(body.toLowerCase().includes("openrouter"), false);
});

test("does not fall back after primary request or authentication errors", async () => {
  for (const status of [400, 401]) {
    let calls = 0;
    const providerFetch = async () => {
      calls += 1;
      return new Response("", { status });
    };

  const response = await handleAuthorizedRequest(createRequest(validBody()), createEnv(), providerFetch);

    assert.equal(response.status, 502);
    assert.equal(calls, 1);
  }
});

test("sanitizes credentials and raw failures when both providers fail", async () => {
  let calls = 0;
  const providerFetch = async (url) => {
    calls += 1;
    if (url === "https://api.openai.com/v1/responses") {
      return new Response(`Authorization Bearer ${openAiSecret}`, { status: 503 });
    }

    return new Response(`Authorization Bearer ${openRouterSecret}`, { status: 503 });
  };

  const response = await handleAuthorizedRequest(createRequest(validBody()), createEnv(), providerFetch);
  const body = await response.text();
  const lowerBody = body.toLowerCase();

  assert.equal(response.status, 502);
  assert.equal(calls, 2);
  assert.equal(body.includes(openAiSecret), false);
  assert.equal(body.includes(openRouterSecret), false);
  assert.equal(body.includes("Authorization"), false);
  assert.equal(lowerBody.includes("openai"), false);
  assert.equal(lowerBody.includes("openrouter"), false);
  assert.match(body, /temporarily unavailable/);
});

test("returns 429 when the tester rate limit is exhausted", async () => {
  const providerFetch = async () => {
    throw new Error("provider must not be called");
  };

  const response = await handleAuthorizedRequest(
    createRequest(validBody()),
    createEnv({ rateLimitSuccess: false }),
    providerFetch,
  );

  assert.equal(response.status, 429);
  assert.equal(response.headers.get("retry-after"), "60");
});

test("production text limiter reserves a normal Mission burst", async () => {
  const config = JSON.parse(
    await readFile(new URL("../wrangler.jsonc", import.meta.url), "utf8"),
  );
  const textLimiter = config.ratelimits.find(
    (binding) => binding.name === "AI_RATE_LIMITER",
  );

  assert.deepEqual(textLimiter?.simple, { limit: 16, period: 60 });
});

test("allows a five-task Mission, one repair, and ordinary Chat in one burst", async () => {
  const limiter = createCountingRateLimiter(16);
  const env = createEnv({ rateLimiter: limiter });
  const activation = await activateDeviceSession(env);
  let providerCalls = 0;

  // Five task outputs, one bounded quality repair, and four ordinary Chat
  // requests are all legitimate work from the same authenticated tester.
  for (let requestIndex = 0; requestIndex < 10; requestIndex += 1) {
    const response = await handleRequest(
      withDeviceSession(createRequest(validBody()), activation.deviceSession),
      env,
      async () => {
        providerCalls += 1;
        return openAiSuccess();
      },
    );

    assert.equal(response.status, 200);
  }

  assert.equal(providerCalls, 10);
  assert.equal(env.quotaCalls(), 10);
  assert.equal(limiter.attempts(), 10);
});

test("allows a ten-task Mission and one bounded repair before throttling abuse", async () => {
  const limiter = createCountingRateLimiter(16);
  const env = createEnv({ rateLimiter: limiter });
  const activation = await activateDeviceSession(env);
  let providerCalls = 0;

  for (let taskAttempt = 0; taskAttempt < 11; taskAttempt += 1) {
    const response = await handleRequest(
      withDeviceSession(createRequest(validBody()), activation.deviceSession),
      env,
      async () => {
        providerCalls += 1;
        return openAiSuccess();
      },
    );

    assert.equal(response.status, 200);
  }

  assert.equal(providerCalls, 11);
  assert.equal(env.quotaCalls(), 11);
  assert.equal(limiter.attempts(), 11);
});

test("rapid requests beyond the Mission burst still receive 429 with Retry-After", async () => {
  const limiter = createCountingRateLimiter(16);
  const env = createEnv({ rateLimiter: limiter });
  const activation = await activateDeviceSession(env);
  let providerCalls = 0;

  for (let attempt = 0; attempt < 16; attempt += 1) {
    const response = await handleRequest(
      withDeviceSession(createRequest(validBody()), activation.deviceSession),
      env,
      async () => {
        providerCalls += 1;
        return openAiSuccess();
      },
    );

    assert.equal(response.status, 200);
  }

  const throttled = await handleRequest(
    withDeviceSession(createRequest(validBody()), activation.deviceSession),
    env,
    async () => {
      providerCalls += 1;
      return openAiSuccess();
    },
  );

  assert.equal(throttled.status, 429);
  assert.equal(throttled.headers.get("retry-after"), "60");
  assert.equal(providerCalls, 16);
  assert.equal(env.quotaCalls(), 16);
  assert.equal(limiter.attempts(), 17);
});

test("image endpoint rejects invalid beta tokens and non-POST requests", async () => {
  const providerFetch = async () => {
    throw new Error("provider must not be called");
  };

  const invalidToken = await handleRequest(
    createImageRequest({ prompt: "Buddha" }, "invalid-token"),
    createEnv(),
    providerFetch,
  );
  const nonPost = await handleRequest(
    createImageRequest(null, betaToken, { method: "GET" }),
    createEnv(),
    providerFetch,
  );

  assert.equal(invalidToken.status, 401);
  assert.equal(nonPost.status, 405);
  assert.equal(nonPost.headers.get("allow"), "POST");
});

test("image endpoint accepts JSON only and rejects malformed, missing, empty, and oversized prompts", async () => {
  const providerFetch = async () => {
    throw new Error("provider must not be called");
  };

  const malformed = await handleAuthorizedRequest(
    createImageRequest("{not-json"),
    createEnv(),
    providerFetch,
  );
  const nonJson = await handleRequest(
    createImageRequest({ prompt: "Buddha" }, betaToken, { contentType: "text/plain" }),
    createEnv(),
    providerFetch,
  );
  const missing = await handleAuthorizedRequest(createImageRequest({}), createEnv(), providerFetch);
  const empty = await handleAuthorizedRequest(
    createImageRequest({ prompt: "   " }),
    createEnv(),
    providerFetch,
  );
  const oversizedPrompt = await handleAuthorizedRequest(
    createImageRequest({ prompt: "x".repeat(4_001) }),
    createEnv(),
    providerFetch,
  );
  const oversizedPayload = await handleAuthorizedRequest(
    createImageRequest({ prompt: "x".repeat(64 * 1024) }),
    createEnv(),
    providerFetch,
  );

  assert.equal(malformed.status, 400);
  assert.equal(nonJson.status, 415);
  assert.equal(missing.status, 400);
  assert.equal(empty.status, 400);
  assert.equal(oversizedPrompt.status, 413);
  assert.equal(oversizedPayload.status, 413);
});

test("image endpoint applies its separate one-per-minute rate limit", async () => {
  const providerFetch = async () => {
    throw new Error("provider must not be called");
  };

  const response = await handleAuthorizedRequest(
    createImageRequest({ prompt: "Buddha" }),
    createEnv({ imageRateLimitSuccess: false }),
    providerFetch,
  );

  assert.equal(response.status, 429);
  assert.equal(response.headers.get("retry-after"), "60");
});

test("image endpoint maps one low-cost OpenAI image request to a neutral response", async () => {
  let upstreamRequest;
  let calls = 0;
  const providerFetch = async (url, options) => {
    calls += 1;
    upstreamRequest = { url, options, body: JSON.parse(options.body) };
    return openAiImageSuccess();
  };

  const response = await handleAuthorizedRequest(
    createImageRequest({ prompt: "  Buddha meditating beneath a bodhi tree  " }),
    createEnv(),
    providerFetch,
  );
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(calls, 1);
  assert.equal(upstreamRequest.url, "https://api.openai.com/v1/images/generations");
  assert.equal(upstreamRequest.options.headers.Authorization, `Bearer ${openAiSecret}`);
  assert.deepEqual(upstreamRequest.body, {
    model: "gpt-image-2",
    prompt: "Buddha meditating beneath a bodhi tree",
    n: 1,
    size: "1024x1024",
    quality: "low",
    output_format: "png",
  });
  assert.deepEqual(payload, {
    image: { mimeType: "image/png", base64: "safe-image-base64" },
  });
  assert.equal(JSON.stringify(payload).toLowerCase().includes("openai"), false);
  assert.equal(JSON.stringify(payload).includes(openAiSecret), false);
});

test("image endpoint sanitizes upstream failures and never calls the text fallback", async () => {
  const calls = [];
  const providerFetch = async (url) => {
    calls.push(url);
    return new Response(`Authorization Bearer ${openAiSecret}`, { status: 503 });
  };

  const response = await handleAuthorizedRequest(
    createImageRequest({ prompt: "Buddha" }),
    createEnv({ includeOpenRouter: true }),
    providerFetch,
  );
  const body = await response.text();
  const lowerBody = body.toLowerCase();

  assert.equal(response.status, 502);
  assert.deepEqual(calls, ["https://api.openai.com/v1/images/generations"]);
  assert.equal(body.includes(openAiSecret), false);
  assert.equal(body.includes(openRouterSecret), false);
  assert.equal(lowerBody.includes("openai"), false);
  assert.equal(lowerBody.includes("openrouter"), false);
  assert.match(body, /couldn't create that image/);
});

test("video transcription is unavailable in the text-first beta before provider invocation", async () => {
  let calls = 0;
  const response = await handleRequest(
    createVideoTranscriptionRequest(),
    createEnv(),
    async () => {
      calls += 1;
      return openAiTranscriptionSuccess();
    },
  );
  const payload = await response.json();

  assert.equal(response.status, 503);
  assert.equal(calls, 0);
  assert.deepEqual(payload, {
    error: {
      code: "beta_video_unavailable",
      message: "Video features are not available in this beta.",
    },
  });
  assert.equal(JSON.stringify(payload).includes(openAiSecret), false);
  assert.equal(JSON.stringify(payload).toLowerCase().includes("provider"), false);
});

test("video transcription short-circuits malformed requests before provider invocation", async () => {
  let calls = 0;
  const providerFetch = async () => {
    calls += 1;
    return openAiTranscriptionSuccess();
  };
  const nonMultipart = await handleRequest(
    createVideoTranscriptionRequest({}, betaToken, { contentType: "application/json" }),
    createEnv(),
    providerFetch,
  );

  assert.equal(nonMultipart.status, 503);
  assert.equal((await nonMultipart.json()).error.code, "beta_video_unavailable");
  assert.equal(calls, 0);
});

test("video edit planning is unavailable in the text-first beta before provider invocation", async () => {
  let calls = 0;
  const providerFetch = async () => {
    calls += 1;
    return openAiVideoEditPlanSuccess();
  };

  const response = await handleRequest(
    createVideoEditPlanRequest(validVideoEditPlanRequest()),
    createEnv(),
    providerFetch,
  );
  const payload = await response.json();

  assert.equal(response.status, 503);
  assert.equal(calls, 0);
  assert.deepEqual(payload, {
    error: {
      code: "beta_video_unavailable",
      message: "Video features are not available in this beta.",
    },
  });
  assert.equal(JSON.stringify(payload).toLowerCase().includes("provider"), false);
});

test("video edit planning short-circuits malformed requests before provider invocation", async () => {
  let calls = 0;
  const response = await handleRequest(
    createVideoEditPlanRequest("{not-json"),
    createEnv(),
    async () => {
      calls += 1;
      return openAiVideoEditPlanSuccess();
    },
  );

  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, "beta_video_unavailable");
  assert.equal(calls, 0);
});

function openAiVideoEditPlanSuccessPlanSegments() {
  return [
    {
      clipId: "clip-one",
      keep: true,
      order: 0,
      trimStartMs: null,
      trimEndMs: null,
    },
    {
      clipId: "clip-two",
      keep: true,
      order: 1,
      trimStartMs: null,
      trimEndMs: null,
    },
  ];
}

test("video edit planning remains unavailable for all request payloads without a provider call", async () => {
  let calls = 0;
  const providerFetch = async () => {
    calls += 1;
    return openAiVideoEditPlanSuccess();
  };
  const withPath = validVideoEditPlanRequest();
  withPath.clips[0].localPath = "/data/user/0/ovexiq/video.mp4";
  const withBytes = validVideoEditPlanRequest();
  withBytes.clips[0].contentAnalysis.videoBytes = "not-allowed";
  const outOfRangeTranscript = validVideoEditPlanRequest();
  outOfRangeTranscript.clips[0].contentAnalysis.transcriptSegments[0].endMs = 15_001;
  const oversizedTranscript = validVideoEditPlanRequest();
  oversizedTranscript.clips[0].contentAnalysis.transcriptSegments[0].text =
    "x".repeat(501);
  const unknownIdResponse = openAiVideoEditPlanSuccess({
    targetDurationMs: 30_000,
    segments: [
      {
        clipId: "not-a-source",
        keep: true,
        order: 0,
        trimStartMs: null,
        trimEndMs: null,
      },
      {
        clipId: "clip-two",
        keep: true,
        order: 1,
        trimStartMs: null,
        trimEndMs: null,
      },
    ],
  });

  const pathResponse = await handleRequest(
    createVideoEditPlanRequest(withPath),
    createEnv(),
    providerFetch,
  );
  const malformedResponse = await handleRequest(
    createVideoEditPlanRequest("{not-json"),
    createEnv(),
    providerFetch,
  );
  const oversizedResponse = await handleRequest(
    createVideoEditPlanRequest({
      ...validVideoEditPlanRequest(),
      instruction: "x".repeat(2_001),
    }),
    createEnv(),
    providerFetch,
  );
  const bytesResponse = await handleRequest(
    createVideoEditPlanRequest(withBytes),
    createEnv(),
    providerFetch,
  );
  const outOfRangeResponse = await handleRequest(
    createVideoEditPlanRequest(outOfRangeTranscript),
    createEnv(),
    providerFetch,
  );
  const oversizedTranscriptResponse = await handleRequest(
    createVideoEditPlanRequest(oversizedTranscript),
    createEnv(),
    providerFetch,
  );

  assert.equal(pathResponse.status, 503);
  assert.equal(malformedResponse.status, 503);
  assert.equal(oversizedResponse.status, 503);
  assert.equal(bytesResponse.status, 503);
  assert.equal(outOfRangeResponse.status, 503);
  assert.equal(oversizedTranscriptResponse.status, 503);
  assert.equal(calls, 0);

  const malformedProvider = await handleRequest(
    createVideoEditPlanRequest(validVideoEditPlanRequest()),
    createEnv(),
    async () => new Response("not-json", { status: 200 }),
  );
  const invalidPlanProvider = await handleRequest(
    createVideoEditPlanRequest(validVideoEditPlanRequest()),
    createEnv(),
    async () => unknownIdResponse,
  );
  const malformedBody = await malformedProvider.text();
  const invalidPlanBody = await invalidPlanProvider.text();

  assert.equal(malformedProvider.status, 503);
  assert.equal(invalidPlanProvider.status, 503);
  assert.equal(malformedBody.includes(openAiSecret), false);
  assert.equal(invalidPlanBody.includes(openAiSecret), false);
  assert.equal(malformedBody.toLowerCase().includes("openai"), false);
  assert.equal(invalidPlanBody.toLowerCase().includes("openai"), false);
});

test("speech endpoint validates access and relays one safe MP3 response", async () => {
  let upstreamBody;
  const response = await handleAuthorizedRequest(
    createSpeechRequest({ text: "  မင်္ဂလာပါ  " }),
    createEnv(),
    async (url, options) => {
      assert.equal(url, "https://api.openai.com/v1/audio/speech");
      assert.equal(options.headers.Authorization, `Bearer ${openAiSecret}`);
      upstreamBody = JSON.parse(options.body);
      return openAiSpeechSuccess();
    },
  );

  assert.equal(response.status, 200);
  assert.equal(response.headers.get("content-type"), "audio/mpeg");
  assert.deepEqual(upstreamBody, {
    model: "gpt-4o-mini-tts",
    voice: "nova",
    input: "မင်္ဂလာပါ",
    response_format: "mp3",
  });
  assert.deepEqual(new Uint8Array(await response.arrayBuffer()), new Uint8Array([1, 2, 3]));
});

test("speech endpoint rejects invalid input before contacting the provider", async () => {
  let calls = 0;
  const providerFetch = async () => {
    calls += 1;
    return openAiSpeechSuccess();
  };
  const invalidToken = await handleRequest(
    createSpeechRequest({ text: "မင်္ဂလာပါ" }, "invalid-token"),
    createEnv(),
    providerFetch,
  );
  const empty = await handleAuthorizedRequest(
    createSpeechRequest({ text: "   " }),
    createEnv(),
    providerFetch,
  );
  const oversized = await handleAuthorizedRequest(
    createSpeechRequest({ text: "x".repeat(4_001) }),
    createEnv(),
    providerFetch,
  );

  assert.equal(invalidToken.status, 401);
  assert.equal(empty.status, 400);
  assert.equal(oversized.status, 413);
  assert.equal(calls, 0);
});

test("legacy quota state normalizes missing speech counters without resetting existing usage", () => {
  const legacyState = {
    day: quotaDay,
    totals: { text: 12, image: 2, retainedCounter: 7 },
    testers: [
      { id: "tester-one", text: 8, image: 1, retainedTesterField: "keep" },
    ],
    retainedStateField: { source: "legacy" },
  };

  assert.deepEqual(normalizeDailyQuotaStateForDay(legacyState, quotaDay), {
    day: quotaDay,
    totals: { text: 12, image: 2, retainedCounter: 7, speech: 0 },
    testers: [
      {
        id: "tester-one",
        text: 8,
        image: 1,
        retainedTesterField: "keep",
        speech: 0,
      },
    ],
    retainedStateField: { source: "legacy" },
  });
});

test("current quota state retains existing speech usage", () => {
  const currentState = {
    day: quotaDay,
    totals: { text: 12, image: 2, speech: 1 },
    testers: [{ id: "tester-one", text: 8, image: 1, speech: 1 }],
  };

  assert.deepEqual(normalizeDailyQuotaStateForDay(currentState, quotaDay), currentState);
});

test("malformed quota state still uses the defensive fresh-state fallback", async () => {
  const { quota, storedState } = createQuotaWithStoredState({
    day: quotaDay,
    totals: { text: "invalid", image: 2 },
    testers: [],
  });

  assert.deepEqual(await quota.consume("tester-one", "text", quotaNow), { allowed: true });
  assert.deepEqual(storedState(), {
    day: quotaDay,
    totals: { text: 1, image: 0, speech: 0 },
    testers: [{ id: "tester-one", text: 1, image: 0, speech: 0 }],
  });
});

test("speech quota increments only speech after normalizing a legacy state", async () => {
  const { quota, storedState } = createQuotaWithStoredState({
    day: quotaDay,
    totals: { text: 12, image: 2 },
    testers: [{ id: "tester-one", text: 8, image: 1 }],
  });

  assert.deepEqual(await quota.consume("tester-one", "speech", quotaNow), { allowed: true });
  assert.deepEqual(storedState(), {
    day: quotaDay,
    totals: { text: 12, image: 2, speech: 1 },
    testers: [{ id: "tester-one", text: 8, image: 1, speech: 1 }],
  });
});

test("a valid invite activates one server-owned account and returns one device session", async () => {
  const env = createEnv();
  const response = await handleRequest(
    createBetaActivationRequest({
      inviteCode: betaInviteCode,
      activationId: "installation-id-abcdefghijklmnopqrstuv",
    }),
    env,
    async () => {
      throw new Error("activation must not call an AI provider");
    },
  );
  const payload = await response.json();

  assert.equal(response.status, 201);
  assert.match(payload.accountId, /^acct_[0-9a-f-]{36}$/);
  assert.match(payload.deviceSession, /^ovs1\.[A-Za-z0-9_-]{32}\.sess_[A-Za-z0-9_-]{32}\.[A-Za-z0-9_-]{43}$/);
  assert.match(payload.recoveryCode, /^orc1_[A-Za-z0-9_-]{32}$/);
  assert.equal(JSON.stringify([...env.BETA_ACCOUNTS.states.values()]).includes(payload.recoveryCode), false);
  assert.equal(JSON.stringify(payload).includes(sessionSigningKey), false);
});

test("activation retry reuses the same account and device session without another recovery secret", async () => {
  const env = createEnv();
  const body = {
    inviteCode: betaInviteCode,
    activationId: "installation-id-abcdefghijklmnopqrstuv",
  };
  const first = await (await handleRequest(createBetaActivationRequest(body), env, globalThis.fetch)).json();
  const retryResponse = await handleRequest(createBetaActivationRequest(body), env, globalThis.fetch);
  const retry = await retryResponse.json();

  assert.equal(retryResponse.status, 200);
  assert.equal(retry.accountId, first.accountId);
  assert.equal(retry.deviceSession, first.deviceSession);
  assert.equal("recoveryCode" in retry, false);
  const state = [...env.BETA_ACCOUNTS.states.values()][0];
  assert.equal(state.sessions.length, 1);
});

test("activation rejects a revoked installation without issuing a replacement session", async () => {
  const env = createEnv();
  const body = {
    inviteCode: betaInviteCode,
    activationId: "installation-id-abcdefghijklmnopqrstuv",
  };
  const activation = await (await handleRequest(
    createBetaActivationRequest(body),
    env,
    globalThis.fetch,
  )).json();
  const account = env.BETA_ACCOUNTS.getByName("ovexiq-beta-account:invite-one");

  assert.deepEqual(await account.revokeSession(activation.deviceSession.split(".")[2]), {
    revoked: true,
  });

  const retryResponse = await handleRequest(
    createBetaActivationRequest(body),
    env,
    globalThis.fetch,
  );
  const retry = await retryResponse.json();

  assert.equal(retryResponse.status, 403);
  assert.equal(retry.error.code, "installation_revoked");
  assert.equal("accountId" in retry, false);
  assert.equal("deviceSession" in retry, false);
  assert.equal("recoveryCode" in retry, false);
  assert.equal(await authenticateBetaDeviceSession(env, activation.deviceSession), null);
});

test("activation rejects an invalid invite without creating an account", async () => {
  const env = createEnv();
  const response = await handleRequest(
    createBetaActivationRequest({
      inviteCode: "not-a-valid-invite",
      activationId: "installation-id-abcdefghijklmnopqrstuv",
    }),
    env,
    globalThis.fetch,
  );
  const payload = await response.json();

  assert.equal(response.status, 401);
  assert.equal(payload.error.code, "invalid_beta_invite");
  assert.equal(env.BETA_ACCOUNTS.states.size, 0);
});

test("a device session resolves only its server-owned account and ignores any client account claim", async () => {
  const env = createEnv();
  env.OVEXIQ_BETA_INVITES = JSON.stringify({
    "invite-one": betaInviteCode,
    "invite-two": "second-closed-beta-invite",
  });
  const first = await (await handleRequest(
    createBetaActivationRequest({
      inviteCode: betaInviteCode,
      activationId: "installation-id-abcdefghijklmnopqrstuv",
    }),
    env,
    globalThis.fetch,
  )).json();
  const second = await (await handleRequest(
    createBetaActivationRequest({
      inviteCode: "second-closed-beta-invite",
      activationId: "another-installation-id-abcdefghijklmnop",
    }),
    env,
    globalThis.fetch,
  )).json();

  const authenticated = await authenticateBetaDeviceSession(env, first.deviceSession);
  const arbitraryClientAccountId = second.accountId;

  assert.deepEqual(authenticated, {
    accountId: first.accountId,
    sessionId: first.deviceSession.split(".")[2],
  });
  assert.notEqual(authenticated.accountId, arbitraryClientAccountId);
});

test("revoked or invalid device sessions cannot authenticate", async () => {
  const env = createEnv();
  const activation = await (await handleRequest(
    createBetaActivationRequest({
      inviteCode: betaInviteCode,
      activationId: "installation-id-abcdefghijklmnopqrstuv",
    }),
    env,
    globalThis.fetch,
  )).json();
  const sessionId = activation.deviceSession.split(".")[2];
  const account = env.BETA_ACCOUNTS.getByName("ovexiq-beta-account:invite-one");

  assert.deepEqual(await account.revokeSession(sessionId), { revoked: true });
  assert.equal(await authenticateBetaDeviceSession(env, activation.deviceSession), null);
  assert.equal(await authenticateBetaDeviceSession(env, "ovs1.invalid.invalid.invalid"), null);
});
