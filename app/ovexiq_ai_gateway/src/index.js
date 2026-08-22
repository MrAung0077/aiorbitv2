const COMPLETE_PATH = "/v1/ai/complete";
const IMAGE_PATH = "/v1/ai/image";
const MAX_BODY_BYTES = 64 * 1024;
const MAX_IMAGE_PROMPT_CHARS = 4_000;
const MAX_MESSAGES = 40;
const MAX_MESSAGE_CHARS = 12_000;
const MAX_TOTAL_MESSAGE_CHARS = 40_000;
const MAX_METADATA_CHARS = 4_096;
const MAX_OUTPUT_TOKENS = 4_096;
const OPENAI_TIMEOUT_MS = 30_000;
const OPENROUTER_TIMEOUT_MS = 20_000;
const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const OPENAI_IMAGES_URL = "https://api.openai.com/v1/images/generations";
const OPENROUTER_CHAT_COMPLETIONS_URL = "https://openrouter.ai/api/v1/chat/completions";
const OPENAI_IMAGE_MODEL = "gpt-image-2";
const ALLOWED_ROLES = new Set(["system", "user", "assistant"]);

export default {
  fetch(request, env) {
    return handleRequest(request, env, globalThis.fetch);
  },
};

export async function handleRequest(request, env, fetchProvider) {
  const url = new URL(request.url);

  if (url.pathname === IMAGE_PATH) {
    return handleImageRequest(request, env, fetchProvider);
  }

  if (url.pathname !== COMPLETE_PATH) {
    return errorResponse(404, "not_found", "Endpoint not found.");
  }

  if (request.method !== "POST") {
    return errorResponse(405, "method_not_allowed", "Use POST for this endpoint.", {
      Allow: "POST",
    });
  }

  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().startsWith("application/json")) {
    return errorResponse(
      415,
      "unsupported_media_type",
      "Content-Type must be application/json.",
    );
  }

  const betaToken = request.headers.get("x-ovexiq-beta-token")?.trim() ?? "";
  const testerId = findTesterId(env.OVEXIQ_BETA_TOKENS, betaToken);

  if (testerId === null) {
    return errorResponse(401, "unauthorized", "Invalid beta access token.");
  }

  const rateLimitResponse = await applyRateLimit(env.AI_RATE_LIMITER, testerId);
  if (rateLimitResponse !== null) {
    return rateLimitResponse;
  }

  const parsedRequest = await parseRequest(request);
  if (parsedRequest.response !== null) {
    return parsedRequest.response;
  }

  return callProvider(parsedRequest.value, env, fetchProvider);
}

async function handleImageRequest(request, env, fetchProvider) {
  if (request.method !== "POST") {
    return errorResponse(405, "method_not_allowed", "Use POST for this endpoint.", {
      Allow: "POST",
    });
  }

  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().startsWith("application/json")) {
    return errorResponse(
      415,
      "unsupported_media_type",
      "Content-Type must be application/json.",
    );
  }

  const betaToken = request.headers.get("x-ovexiq-beta-token")?.trim() ?? "";
  const testerId = findTesterId(env.OVEXIQ_BETA_TOKENS, betaToken);

  if (testerId === null) {
    return errorResponse(401, "unauthorized", "Invalid beta access token.");
  }

  const rateLimitResponse = await applyRateLimit(env.IMAGE_RATE_LIMITER, testerId);
  if (rateLimitResponse !== null) {
    return rateLimitResponse;
  }

  const parsedRequest = await parseImageRequest(request);
  if (parsedRequest.response !== null) {
    return parsedRequest.response;
  }

  return callOpenAiImage(parsedRequest.value, env, fetchProvider);
}

function findTesterId(configuredTokens, presentedToken) {
  if (typeof configuredTokens !== "string" || presentedToken.length === 0) {
    return null;
  }

  let tokens;
  try {
    tokens = JSON.parse(configuredTokens);
  } catch {
    return null;
  }

  if (tokens === null || typeof tokens !== "object" || Array.isArray(tokens)) {
    return null;
  }

  for (const [testerId, token] of Object.entries(tokens)) {
    if (
      testerId.trim().length > 0 &&
      typeof token === "string" &&
      token.length > 0 &&
      token === presentedToken
    ) {
      return testerId.slice(0, 64);
    }
  }

  return null;
}

async function applyRateLimit(rateLimiter, testerId) {
  if (rateLimiter === null || typeof rateLimiter?.limit !== "function") {
    return errorResponse(
      503,
      "rate_limit_unavailable",
      "Ovexiq AI is temporarily unavailable.",
    );
  }

  try {
    const result = await rateLimiter.limit({ key: `beta:${testerId}` });
    if (result?.success === true) {
      return null;
    }

    return errorResponse(429, "rate_limited", "Too many requests. Try again shortly.", {
      "Retry-After": "60",
    });
  } catch {
    return errorResponse(
      503,
      "rate_limit_unavailable",
      "Ovexiq AI is temporarily unavailable.",
    );
  }
}

async function parseRequest(request) {
  let rawBody;
  try {
    rawBody = await request.text();
  } catch {
    return failure(400, "invalid_json", "Request body must be valid JSON.");
  }

  if (new TextEncoder().encode(rawBody).byteLength > MAX_BODY_BYTES) {
    return failure(413, "payload_too_large", "Request payload is too large.");
  }

  let body;
  try {
    body = JSON.parse(rawBody);
  } catch {
    return failure(400, "invalid_json", "Request body must be valid JSON.");
  }

  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    return failure(400, "invalid_request", "Request body must be a JSON object.");
  }

  if (!Array.isArray(body.messages) || body.messages.length === 0) {
    return failure(400, "invalid_messages", "At least one message is required.");
  }

  if (body.messages.length > MAX_MESSAGES) {
    return failure(413, "too_many_messages", "Too many messages were provided.");
  }

  const messages = [];
  let totalMessageChars = 0;

  for (const message of body.messages) {
    if (message === null || typeof message !== "object" || Array.isArray(message)) {
      return failure(400, "invalid_message", "Each message must be an object.");
    }

    if (!ALLOWED_ROLES.has(message.role) || typeof message.content !== "string") {
      return failure(400, "invalid_message", "Each message requires a valid role and text content.");
    }

    const content = message.content.trim();
    if (content.length === 0) {
      return failure(400, "empty_message", "Message content cannot be empty.");
    }

    if (content.length > MAX_MESSAGE_CHARS) {
      return failure(413, "message_too_large", "A message is too large.");
    }

    totalMessageChars += content.length;
    if (totalMessageChars > MAX_TOTAL_MESSAGE_CHARS) {
      return failure(413, "messages_too_large", "Combined message content is too large.");
    }

    messages.push({ role: message.role, content });
  }

  let temperature;
  if (body.temperature !== undefined) {
    if (
      typeof body.temperature !== "number" ||
      !Number.isFinite(body.temperature) ||
      body.temperature < 0 ||
      body.temperature > 2
    ) {
      return failure(400, "invalid_temperature", "Temperature must be between 0 and 2.");
    }
    temperature = body.temperature;
  }

  let maxTokens;
  if (body.maxTokens !== undefined) {
    if (
      !Number.isInteger(body.maxTokens) ||
      body.maxTokens < 1 ||
      body.maxTokens > MAX_OUTPUT_TOKENS
    ) {
      return failure(
        400,
        "invalid_max_tokens",
        `maxTokens must be between 1 and ${MAX_OUTPUT_TOKENS}.`,
      );
    }
    maxTokens = body.maxTokens;
  }

  let metadata;
  if (body.metadata !== undefined) {
    if (body.metadata === null || typeof body.metadata !== "object" || Array.isArray(body.metadata)) {
      return failure(400, "invalid_metadata", "metadata must be a JSON object.");
    }

    const encodedMetadata = JSON.stringify(body.metadata);
    if (encodedMetadata.length > MAX_METADATA_CHARS) {
      return failure(413, "metadata_too_large", "metadata is too large.");
    }
    metadata = body.metadata;
  }

  return {
    response: null,
    value: { messages, temperature, maxTokens, metadata },
  };
}

async function parseImageRequest(request) {
  let rawBody;
  try {
    rawBody = await request.text();
  } catch {
    return failure(400, "invalid_json", "Request body must be valid JSON.");
  }

  if (new TextEncoder().encode(rawBody).byteLength > MAX_BODY_BYTES) {
    return failure(413, "payload_too_large", "Request payload is too large.");
  }

  let body;
  try {
    body = JSON.parse(rawBody);
  } catch {
    return failure(400, "invalid_json", "Request body must be valid JSON.");
  }

  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    return failure(400, "invalid_request", "Request body must be a JSON object.");
  }

  if (typeof body.prompt !== "string") {
    return failure(400, "invalid_prompt", "A prompt is required.");
  }

  const prompt = body.prompt.trim();
  if (prompt.length === 0) {
    return failure(400, "empty_prompt", "A prompt is required.");
  }

  if (prompt.length > MAX_IMAGE_PROMPT_CHARS) {
    return failure(413, "prompt_too_large", "Prompt is too large.");
  }

  return { response: null, value: { prompt } };
}

async function callProvider(input, env, fetchProvider) {
  const openAiResult = await callOpenAi(input, env, fetchProvider);
  if (openAiResult.response !== null) {
    return openAiResult.response;
  }

  if (!openAiResult.canFallback) {
    return openAiResult.failureResponse;
  }

  const openRouterResponse = await callOpenRouter(input, env, fetchProvider);
  return openRouterResponse ?? openAiResult.failureResponse;
}

async function callOpenAi(input, env, fetchProvider) {
  const providerApiKey = configuredValue(env.OPENAI_API_KEY);
  const model = configuredValue(env.OPENAI_MODEL);

  if (providerApiKey.length === 0 || model.length === 0) {
    return providerFailure(503, "provider_unavailable", "Ovexiq AI is temporarily unavailable.");
  }

  const providerBody = {
    model,
    input: input.messages,
    store: false,
    max_output_tokens: input.maxTokens ?? MAX_OUTPUT_TOKENS,
  };

  const fetchResult = await fetchWithTimeout(
    fetchProvider,
    OPENAI_RESPONSES_URL,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${providerApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(providerBody),
    },
    OPENAI_TIMEOUT_MS,
  );

  if (fetchResult.error !== null) {
    if (fetchResult.timedOut) {
      return providerFailure(504, "provider_timeout", "Ovexiq AI timed out. Please try again.", true);
    }

    return providerFailure(502, "provider_failure", "Ovexiq AI is temporarily unavailable.", true);
  }

  const providerResponse = fetchResult.response;
  if (!providerResponse.ok) {
    return providerFailure(
      502,
      "provider_failure",
      "Ovexiq AI is temporarily unavailable.",
      providerResponse.status === 429 || providerResponse.status >= 500,
    );
  }

  let providerPayload;
  try {
    providerPayload = await providerResponse.json();
  } catch {
    return providerFailure(
      502,
      "invalid_provider_response",
      "Ovexiq AI returned an invalid response.",
      true,
    );
  }

  const content = extractOutputText(providerPayload);
  if (content.length === 0) {
    return providerFailure(
      502,
      "empty_provider_response",
      "Ovexiq AI returned an empty response.",
      true,
    );
  }

  const usage = providerPayload?.usage;
  return providerSuccess({
    content,
    ...(typeof providerPayload?.model === "string" ? { model: providerPayload.model } : {}),
    ...(typeof providerPayload?.id === "string" ? { requestId: providerPayload.id } : {}),
    ...(usage !== null && typeof usage === "object"
      ? {
          usage: {
            ...(Number.isInteger(usage.input_tokens)
              ? { promptTokens: usage.input_tokens }
              : {}),
            ...(Number.isInteger(usage.output_tokens)
              ? { completionTokens: usage.output_tokens }
              : {}),
          },
        }
      : {}),
  });
}

async function callOpenAiImage(input, env, fetchProvider) {
  const providerApiKey = configuredValue(env.OPENAI_API_KEY);

  if (providerApiKey.length === 0) {
    return errorResponse(
      503,
      "image_generation_unavailable",
      "Ovexiq image generation is temporarily unavailable.",
    );
  }

  const fetchResult = await fetchWithTimeout(
    fetchProvider,
    OPENAI_IMAGES_URL,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${providerApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: OPENAI_IMAGE_MODEL,
        prompt: input.prompt,
        n: 1,
        size: "1024x1024",
        quality: "low",
        output_format: "png",
      }),
    },
    OPENAI_TIMEOUT_MS,
  );

  if (fetchResult.error !== null) {
    return errorResponse(
      fetchResult.timedOut ? 504 : 502,
      "image_generation_failed",
      fetchResult.timedOut
        ? "Ovexiq image generation timed out. Please try again."
        : "Ovexiq couldn't create that image. Please try again.",
    );
  }

  if (!fetchResult.response.ok) {
    return errorResponse(
      502,
      "image_generation_failed",
      "Ovexiq couldn't create that image. Please try again.",
    );
  }

  let providerPayload;
  try {
    providerPayload = await fetchResult.response.json();
  } catch {
    return errorResponse(
      502,
      "image_generation_failed",
      "Ovexiq couldn't create that image. Please try again.",
    );
  }

  const base64 = providerPayload?.data?.[0]?.b64_json;
  if (typeof base64 !== "string" || base64.trim().length === 0) {
    return errorResponse(
      502,
      "image_generation_failed",
      "Ovexiq couldn't create that image. Please try again.",
    );
  }

  return jsonResponse({
    image: {
      mimeType: "image/png",
      base64: base64.trim(),
    },
  });
}

async function callOpenRouter(input, env, fetchProvider) {
  const providerApiKey = configuredValue(env.OPENROUTER_API_KEY);
  const model = configuredValue(env.OPENROUTER_MODEL);

  if (providerApiKey.length === 0 || model.length === 0) {
    return null;
  }

  const fetchResult = await fetchWithTimeout(
    fetchProvider,
    OPENROUTER_CHAT_COMPLETIONS_URL,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${providerApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        messages: input.messages,
        max_tokens: input.maxTokens ?? MAX_OUTPUT_TOKENS,
        ...(input.temperature !== undefined ? { temperature: input.temperature } : {}),
      }),
    },
    OPENROUTER_TIMEOUT_MS,
  );

  if (fetchResult.error !== null || !fetchResult.response.ok) {
    return null;
  }

  let providerPayload;
  try {
    providerPayload = await fetchResult.response.json();
  } catch {
    return null;
  }

  const content = extractOpenRouterOutputText(providerPayload);
  if (content.length === 0) {
    return null;
  }

  const usage = providerPayload?.usage;
  return jsonResponse({
    content,
    ...(usage !== null && typeof usage === "object"
      ? {
          usage: {
            ...(Number.isInteger(usage.prompt_tokens)
              ? { promptTokens: usage.prompt_tokens }
              : {}),
            ...(Number.isInteger(usage.completion_tokens)
              ? { completionTokens: usage.completion_tokens }
              : {}),
          },
        }
      : {}),
  });
}

async function fetchWithTimeout(fetchProvider, url, options, timeoutMs) {
  const abortController = new AbortController();
  const timeoutId = setTimeout(() => abortController.abort(), timeoutMs);

  try {
    const response = await fetchProvider(url, { ...options, signal: abortController.signal });
    return { response, error: null, timedOut: false };
  } catch (error) {
    return {
      response: null,
      error,
      timedOut: abortController.signal.aborted || error?.name === "AbortError",
    };
  } finally {
    clearTimeout(timeoutId);
  }
}

function extractOutputText(payload) {
  if (!Array.isArray(payload?.output)) {
    return "";
  }

  let result = "";
  for (const item of payload.output) {
    if (!Array.isArray(item?.content)) {
      continue;
    }

    for (const part of item.content) {
      if (part?.type === "output_text" && typeof part.text === "string") {
        result += part.text;
      }
    }
  }

  return result.trim();
}

function extractOpenRouterOutputText(payload) {
  if (!Array.isArray(payload?.choices) || payload.choices.length === 0) {
    return "";
  }

  const content = payload.choices[0]?.message?.content;
  return typeof content === "string" ? content.trim() : "";
}

function configuredValue(value) {
  return typeof value === "string" ? value.trim() : "";
}

function providerSuccess(response) {
  return { response: jsonResponse(response), failureResponse: null, canFallback: false };
}

function providerFailure(status, code, message, canFallback = false) {
  return {
    response: null,
    failureResponse: errorResponse(status, code, message),
    canFallback,
  };
}

function failure(status, code, message) {
  return { response: errorResponse(status, code, message), value: null };
}

function errorResponse(status, code, message, headers = {}) {
  return jsonResponse({ error: { code, message } }, status, headers);
}

function jsonResponse(payload, status = 200, headers = {}) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      ...headers,
    },
  });
}
