import assert from "node:assert/strict";
import test from "node:test";

import { handleRequest } from "../src/index.js";

const gatewayUrl = "https://gateway.example.test/v1/ai/complete";
const betaToken = "revocable-tester-token";
const openAiSecret = "openai-test-secret-must-not-leak";
const geminiSecret = "gemini-test-secret-must-not-leak";

function createEnv({ rateLimitSuccess = true, includeGemini = true } = {}) {
  const env = {
    OPENAI_API_KEY: openAiSecret,
    OPENAI_MODEL: "openai-test-model",
    OVEXIQ_BETA_TOKENS: JSON.stringify({ "tester-one": betaToken }),
    AI_RATE_LIMITER: {
      async limit({ key }) {
        assert.equal(key, "beta:tester-one");
        return { success: rateLimitSuccess };
      },
    },
  };

  if (includeGemini) {
    env.GEMINI_API_KEY = geminiSecret;
    env.GEMINI_MODEL = "gemini-3.6-flash";
  }

  return env;
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

function geminiSuccess(text = "Fallback result") {
  return new Response(
    JSON.stringify({
      candidates: [{ content: { parts: [{ text }] } }],
      usageMetadata: { promptTokenCount: 31, candidatesTokenCount: 13 },
    }),
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

test("rejects malformed and oversized payloads", async () => {
  const providerFetch = async () => {
    throw new Error("provider must not be called");
  };

  const malformed = await handleRequest(
    createRequest("{not-json"),
    createEnv(),
    providerFetch,
  );
  const oversized = await handleRequest(
    createRequest({ messages: [{ role: "user", content: "x".repeat(12_001) }] }),
    createEnv(),
    providerFetch,
  );

  assert.equal(malformed.status, 400);
  assert.equal(oversized.status, 413);
});

test("uses OpenAI as the primary provider when it succeeds", async () => {
  let upstreamBody;
  let calls = 0;
  const providerFetch = async (url, options) => {
    calls += 1;
    assert.equal(url, "https://api.openai.com/v1/responses");
    assert.equal(options.headers.Authorization, `Bearer ${openAiSecret}`);
    upstreamBody = JSON.parse(options.body);
    return openAiSuccess();
  };

  const response = await handleRequest(createRequest(validBody()), createEnv(), providerFetch);
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

      assert.match(url, /generativelanguage\.googleapis\.com/);
      return geminiSuccess(transientFailure.name);
    };

    const response = await handleRequest(createRequest(validBody()), createEnv(), providerFetch);
    const payload = await response.json();

    assert.equal(response.status, 200, transientFailure.name);
    assert.equal(payload.content, transientFailure.name);
    assert.equal(calls, 2, transientFailure.name);
  }
});

test("maps the neutral request to Gemini and keeps its credential backend-only", async () => {
  let geminiRequest;
  const providerFetch = async (url, options) => {
    if (url === "https://api.openai.com/v1/responses") {
      return new Response("", { status: 503 });
    }

    geminiRequest = { url, options, body: JSON.parse(options.body) };
    return geminiSuccess();
  };

  const response = await handleRequest(createRequest(validBody()), createEnv(), providerFetch);
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(
    geminiRequest.url,
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent",
  );
  assert.equal(geminiRequest.url.includes(geminiSecret), false);
  assert.equal(geminiRequest.options.headers["x-goog-api-key"], geminiSecret);
  assert.equal("Authorization" in geminiRequest.options.headers, false);
  assert.deepEqual(geminiRequest.body, {
    contents: [
      { role: "user", parts: [{ text: "Research Kaspa." }] },
      { role: "model", parts: [{ text: "Prior accepted result." }] },
      { role: "user", parts: [{ text: "Summarize it." }] },
    ],
    systemInstruction: { parts: [{ text: "Be concise." }] },
    generationConfig: { maxOutputTokens: 800 },
  });
  assert.deepEqual(payload, {
    content: "Fallback result",
    usage: { promptTokens: 31, completionTokens: 13 },
  });
  assert.equal(JSON.stringify(payload).toLowerCase().includes("gemini"), false);
  assert.equal(JSON.stringify(payload).includes(geminiSecret), false);
});

test("does not fall back when Gemini is not configured", async () => {
  let calls = 0;
  const providerFetch = async () => {
    calls += 1;
    return new Response("", { status: 503 });
  };

  const response = await handleRequest(
    createRequest(validBody()),
    createEnv({ includeGemini: false }),
    providerFetch,
  );
  const body = await response.text();

  assert.equal(response.status, 502);
  assert.equal(calls, 1);
  assert.equal(body.toLowerCase().includes("gemini"), false);
});

test("does not fall back after primary request or authentication errors", async () => {
  for (const status of [400, 401]) {
    let calls = 0;
    const providerFetch = async () => {
      calls += 1;
      return new Response("", { status });
    };

    const response = await handleRequest(createRequest(validBody()), createEnv(), providerFetch);

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

    return new Response(`x-goog-api-key ${geminiSecret}`, { status: 503 });
  };

  const response = await handleRequest(createRequest(validBody()), createEnv(), providerFetch);
  const body = await response.text();
  const lowerBody = body.toLowerCase();

  assert.equal(response.status, 502);
  assert.equal(calls, 2);
  assert.equal(body.includes(openAiSecret), false);
  assert.equal(body.includes(geminiSecret), false);
  assert.equal(body.includes("Authorization"), false);
  assert.equal(lowerBody.includes("openai"), false);
  assert.equal(lowerBody.includes("gemini"), false);
  assert.match(body, /temporarily unavailable/);
});

test("returns 429 when the tester rate limit is exhausted", async () => {
  const providerFetch = async () => {
    throw new Error("provider must not be called");
  };

  const response = await handleRequest(
    createRequest(validBody()),
    createEnv({ rateLimitSuccess: false }),
    providerFetch,
  );

  assert.equal(response.status, 429);
  assert.equal(response.headers.get("retry-after"), "60");
});
