import assert from "node:assert/strict";
import test from "node:test";

import { handleRequest } from "../src/index.js";

const gatewayUrl = "https://gateway.example.test/v1/ai/complete";
const imageGatewayUrl = "https://gateway.example.test/v1/ai/image";
const betaToken = "revocable-tester-token";
const openAiSecret = "openai-test-secret-must-not-leak";
const openRouterSecret = "openrouter-test-secret-must-not-leak";

function createEnv({
  rateLimitSuccess = true,
  imageRateLimitSuccess = true,
  includeOpenRouter = true,
} = {}) {
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
    IMAGE_RATE_LIMITER: {
      async limit({ key }) {
        assert.equal(key, "beta:tester-one");
        return { success: imageRateLimitSuccess };
      },
    },
  };

  if (includeOpenRouter) {
    env.OPENROUTER_API_KEY = openRouterSecret;
    env.OPENROUTER_MODEL = "mistralai/mistral-small-2603";
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

      assert.equal(url, "https://openrouter.ai/api/v1/chat/completions");
      return openRouterSuccess(transientFailure.name);
    };

    const response = await handleRequest(createRequest(validBody()), createEnv(), providerFetch);
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

  const response = await handleRequest(createRequest(validBody()), createEnv(), providerFetch);
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

  const response = await handleRequest(createRequest(requestBody), createEnv(), providerFetch);

  assert.equal(response.status, 200);
  assert.equal("temperature" in openRouterBody, false);
});

test("does not fall back when OpenRouter is not configured", async () => {
  let calls = 0;
  const providerFetch = async () => {
    calls += 1;
    return new Response("", { status: 503 });
  };

  const response = await handleRequest(
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

    return new Response(`Authorization Bearer ${openRouterSecret}`, { status: 503 });
  };

  const response = await handleRequest(createRequest(validBody()), createEnv(), providerFetch);
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

  const response = await handleRequest(
    createRequest(validBody()),
    createEnv({ rateLimitSuccess: false }),
    providerFetch,
  );

  assert.equal(response.status, 429);
  assert.equal(response.headers.get("retry-after"), "60");
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

  const malformed = await handleRequest(
    createImageRequest("{not-json"),
    createEnv(),
    providerFetch,
  );
  const nonJson = await handleRequest(
    createImageRequest({ prompt: "Buddha" }, betaToken, { contentType: "text/plain" }),
    createEnv(),
    providerFetch,
  );
  const missing = await handleRequest(createImageRequest({}), createEnv(), providerFetch);
  const empty = await handleRequest(
    createImageRequest({ prompt: "   " }),
    createEnv(),
    providerFetch,
  );
  const oversizedPrompt = await handleRequest(
    createImageRequest({ prompt: "x".repeat(4_001) }),
    createEnv(),
    providerFetch,
  );
  const oversizedPayload = await handleRequest(
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

  const response = await handleRequest(
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

  const response = await handleRequest(
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

  const response = await handleRequest(
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
