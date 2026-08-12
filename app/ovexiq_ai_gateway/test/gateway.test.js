import assert from "node:assert/strict";
import test from "node:test";

import { handleRequest } from "../src/index.js";

const gatewayUrl = "https://gateway.example.test/v1/ai/complete";
const betaToken = "revocable-tester-token";
const providerSecret = "provider-secret-must-never-leak";

function createEnv({ rateLimitSuccess = true } = {}) {
  return {
    OPENAI_API_KEY: providerSecret,
    OPENAI_MODEL: "test-model",
    OVEXIQ_BETA_TOKENS: JSON.stringify({ "tester-one": betaToken }),
    AI_RATE_LIMITER: {
      async limit({ key }) {
        assert.equal(key, "beta:tester-one");
        return { success: rateLimitSuccess };
      },
    },
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

test("normalizes a successful provider response", async () => {
  let upstreamBody;
  const providerFetch = async (url, options) => {
    assert.equal(url, "https://api.openai.com/v1/responses");
    assert.equal(options.headers.Authorization, `Bearer ${providerSecret}`);
    upstreamBody = JSON.parse(options.body);

    return new Response(
      JSON.stringify({
        id: "provider-request-id",
        model: "test-model",
        output: [
          {
            content: [{ type: "output_text", text: "Normalized result" }],
          },
        ],
        usage: { input_tokens: 42, output_tokens: 17 },
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  };

  const response = await handleRequest(createRequest(validBody()), createEnv(), providerFetch);
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.deepEqual(upstreamBody.input, validBody().messages);
  assert.equal(upstreamBody.store, false);
  assert.equal(upstreamBody.temperature, 0.4);
  assert.equal(upstreamBody.max_output_tokens, 800);
  assert.deepEqual(payload, {
    content: "Normalized result",
    model: "test-model",
    requestId: "provider-request-id",
    usage: { promptTokens: 42, completionTokens: 17 },
  });
});

test("never returns provider secrets or raw provider failures", async () => {
  const providerFetch = async () =>
    new Response(
      JSON.stringify({
        error: {
          message: `Authorization Bearer ${providerSecret}`,
          stack: "raw provider stack trace",
        },
      }),
      { status: 401, headers: { "Content-Type": "application/json" } },
    );

  const response = await handleRequest(createRequest(validBody()), createEnv(), providerFetch);
  const body = await response.text();

  assert.equal(response.status, 502);
  assert.equal(body.includes(providerSecret), false);
  assert.equal(body.includes("raw provider stack trace"), false);
  assert.equal(body.includes("Authorization"), false);
});

test("sanitizes provider connection failures", async () => {
  const providerFetch = async () => {
    throw new Error(`connection failed with ${providerSecret}`);
  };

  const response = await handleRequest(createRequest(validBody()), createEnv(), providerFetch);
  const body = await response.text();

  assert.equal(response.status, 502);
  assert.equal(body.includes(providerSecret), false);
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
