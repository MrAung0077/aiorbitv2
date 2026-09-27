import { DurableObject } from "cloudflare:workers";

const COMPLETE_PATH = "/v1/ai/complete";
const IMAGE_PATH = "/v1/ai/image";
const SPEECH_PATH = "/v1/ai/speech";
const BETA_ACTIVATE_PATH = "/v1/beta/activate";
const DEVICE_SESSION_HEADER = "x-ovexiq-device-session";
const VIDEO_EDIT_PLAN_PATH = "/v1/ai/video/edit-plan";
const VIDEO_TRANSCRIBE_PATH = "/v1/ai/video/transcribe";
const MAX_BODY_BYTES = 64 * 1024;
const MAX_IMAGE_PROMPT_CHARS = 4_000;
const MAX_NARRATION_CHARS = 4_000;
const MAX_VIDEO_EDIT_INSTRUCTION_CHARS = 2_000;
const MAX_VIDEO_CLIPS = 5;
const MIN_VIDEO_CLIPS = 1;
const MAX_VIDEO_CLIP_ID_CHARS = 128;
const MAX_VIDEO_DURATION_MS = 60 * 60 * 1_000;
const MAX_VIDEO_DIMENSION = 8_192;
const MAX_VIDEO_FRAME_RATE = 240;
const MAX_VIDEO_FILE_SIZE_BYTES = 500 * 1024 * 1024;
const MAX_VIDEO_TARGET_DURATION_MS = 10 * 60 * 1_000;
const MAX_VIDEO_CONTENT_ANALYSIS_BYTES = 24 * 1024;
const MAX_VIDEO_ANALYSIS_VERSION_CHARS = 64;
const MAX_VIDEO_TRANSCRIPT_SEGMENTS_PER_CLIP = 40;
const MAX_VIDEO_SCENE_SEGMENTS_PER_CLIP = 40;
const MAX_VIDEO_AUDIO_ACTIVITY_SEGMENTS_PER_CLIP = 60;
const MAX_VIDEO_ANALYSIS_SEGMENTS_TOTAL = 200;
const MAX_VIDEO_TRANSCRIPT_SEGMENT_CHARS = 500;
const MAX_VIDEO_TRANSCRIPT_CHARS_TOTAL = 12_000;
const MAX_VIDEO_SCENE_LABEL_CHARS = 80;
const MAX_TRANSCRIPTION_AUDIO_BYTES = 10 * 1024 * 1024;
const MAX_TRANSCRIPTION_CLIP_ID_CHARS = 128;
const MAX_TRANSCRIPTION_SEGMENTS = 120;
const MAX_TRANSCRIPTION_SEGMENT_CHARS = 500;
const MAX_TRANSCRIPTION_TEXT_CHARS = 12_000;
const MAX_TRANSCRIPTION_DURATION_MS = 10 * 60 * 1_000;
const MAX_MESSAGES = 40;
const MAX_MESSAGE_CHARS = 12_000;
const MAX_TOTAL_MESSAGE_CHARS = 40_000;
const MAX_METADATA_CHARS = 4_096;
const MAX_OUTPUT_TOKENS = 4_096;
const MAX_BURMESE_OUTPUT_TOKENS = 1_800;
const OPENAI_TIMEOUT_MS = 30_000;
const OPENROUTER_TIMEOUT_MS = 20_000;
// Cloudflare permits an HTTP Worker to wait on a subrequest while the client
// remains connected. Burmese Mission responses can legitimately need longer
// than the standard route, so keep this narrowly scoped to that route.
const BURMESE_STRONG_TIMEOUT_MS = 75_000;
const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const OPENAI_IMAGES_URL = "https://api.openai.com/v1/images/generations";
const OPENAI_SPEECH_URL = "https://api.openai.com/v1/audio/speech";
const OPENAI_TRANSCRIPTIONS_URL = "https://api.openai.com/v1/audio/transcriptions";
const OPENROUTER_CHAT_COMPLETIONS_URL = "https://openrouter.ai/api/v1/chat/completions";
const OPENAI_IMAGE_MODEL = "gpt-image-2";
const OPENAI_SPEECH_MODEL = "gpt-4o-mini-tts";
const OPENAI_SPEECH_VOICE = "nova";
const OPENAI_TRANSCRIPTION_MODEL = "whisper-1";
const BURMESE_STRONG_MODEL = "openai/gpt-6-astra";
const RESPONSE_LANGUAGES = new Set(["my", "en", "auto"]);
const ALLOWED_ROLES = new Set(["system", "user", "assistant"]);
const DAILY_QUOTA_OBJECT_NAME = "ovexiq-beta-daily-quota";
const DAILY_QUOTA_STATE_KEY = "current-day";
const BETA_ACCOUNT_STATE_KEY = "beta-account";
const BETA_ACCOUNT_OBJECT_PREFIX = "ovexiq-beta-account:";
const MAX_BETA_INVITE_CODE_CHARS = 256;
const MIN_ACTIVATION_ID_CHARS = 22;
const MAX_ACTIVATION_ID_CHARS = 128;
const DAILY_QUOTA_LIMITS = Object.freeze({
  text: Object.freeze({ perTester: 30, global: 90 }),
  image: Object.freeze({ perTester: 2, global: 3 }),
  speech: Object.freeze({ perTester: 2, global: 3 }),
});
const ALLOWED_VIDEO_ORIENTATIONS = new Set(["portrait", "landscape", "square"]);
const ALLOWED_TRANSCRIPTION_AUDIO_TYPES = new Set(["audio/mp4", "audio/m4a", "audio/aac"]);
const VIDEO_EDIT_PLAN_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["targetDurationMs", "segments"],
  properties: {
    targetDurationMs: { type: ["integer", "null"] },
    segments: {
      type: "array",
      minItems: MIN_VIDEO_CLIPS,
      maxItems: MAX_VIDEO_CLIPS,
      items: {
        type: "object",
        additionalProperties: false,
        required: ["clipId", "keep", "order", "trimStartMs", "trimEndMs"],
        properties: {
          clipId: { type: "string" },
          keep: { type: "boolean" },
          order: { type: "integer" },
          trimStartMs: { type: ["integer", "null"] },
          trimEndMs: { type: ["integer", "null"] },
        },
      },
    },
  },
};
const VIDEO_EDIT_PLAN_INSTRUCTIONS = [
  "Create a conservative local video edit plan from supplied metadata and optional bounded content signals.",
  "Return only the requested JSON schema.",
  "Use semantic claims only when corresponding supplied transcript, scene, or audio signals support them. If those signals are absent, do not claim to identify boring parts, best moments, people, scenes, or spoken content.",
  "Preserve source order unless duration, orientation, or the user's explicit non-semantic preference justifies a conservative change.",
  "When output.targetDurationMs is supplied, it is a hard requirement: targetDurationMs must equal it and the total kept segment duration MUST be within 1000 ms of it. Never return a longer plan.",
  "Every input clip must have exactly one decision. Use only the supplied opaque clip IDs.",
  "Do not include prose, markdown, paths, provider data, or export commands.",
].join(" ");

export default {
  fetch(request, env) {
    return handleRequest(request, env, globalThis.fetch);
  },
};

export async function handleRequest(request, env, fetchProvider) {
  try {
    return await handleRoutedRequest(request, env, fetchProvider);
  } catch {
    return errorResponse(
      503,
      "service_unavailable",
      "Ovexiq AI is temporarily unavailable. Please try again later.",
    );
  }
}
async function handleRoutedRequest(request, env, fetchProvider) {
  const url = new URL(request.url);

  if (url.pathname === BETA_ACTIVATE_PATH) {
    return handleBetaActivationRequest(request, env);
  }

  if (url.pathname === IMAGE_PATH) {
    return handleImageRequest(request, env, fetchProvider);
  }

  if (url.pathname === SPEECH_PATH) {
    return handleSpeechRequest(request, env, fetchProvider);
  }

  if (url.pathname === VIDEO_EDIT_PLAN_PATH) {
    return handleVideoEditPlanRequest(request, env, fetchProvider);
  }

  if (url.pathname === VIDEO_TRANSCRIBE_PATH) {
    return handleVideoTranscriptionRequest(request, env, fetchProvider);
  }

  if (url.pathname !== COMPLETE_PATH) {
    return errorResponse(404, "not_found", "Endpoint not found.");
  }

  return handleTextRequest(request, env, fetchProvider);
}

async function handleBetaActivationRequest(request, env) {
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

  if (isBetaAiDisabled(env.OVEXIQ_BETA_AI_DISABLED)) {
    return betaDisabledResponse();
  }

  const betaToken = request.headers.get("x-ovexiq-beta-token")?.trim() ?? "";
  const testerId = await findTesterId(env.OVEXIQ_BETA_TOKENS, betaToken);
  if (testerId === null) {
    return errorResponse(401, "unauthorized", "Invalid beta access token.");
  }

  const parsedRequest = await parseBetaActivationRequest(request);
  if (parsedRequest.response !== null) {
    return parsedRequest.response;
  }

  const inviteId = await findInviteId(
    env.OVEXIQ_BETA_INVITES,
    parsedRequest.value.inviteCode,
  );
  if (inviteId === null) {
    return errorResponse(401, "invalid_beta_invite", "Invalid beta invite.");
  }

  const accounts = env.BETA_ACCOUNTS;
  if (accounts === null || typeof accounts?.getByName !== "function") {
    return errorResponse(
      503,
      "beta_identity_unavailable",
      "Beta activation is temporarily unavailable.",
    );
  }
  if (configuredValue(env.OVEXIQ_SESSION_SIGNING_KEY).length < 32) {
    return errorResponse(
      503,
      "beta_identity_unavailable",
      "Beta activation is temporarily unavailable.",
    );
  }

  try {
    const account = accounts.getByName(betaAccountObjectName(inviteId));
    const activation = await account.activate({
      inviteId,
      activationId: parsedRequest.value.activationId,
    });
    if (activation?.status === "disabled") {
      return errorResponse(403, "account_disabled", "This beta account is disabled.");
    }
    if (activation?.status === "revoked") {
      return errorResponse(
        403,
        "installation_revoked",
        "This beta installation has been revoked.",
      );
    }
    if (!isValidActivationResult(activation)) {
      return errorResponse(
        503,
        "beta_identity_unavailable",
        "Beta activation is temporarily unavailable.",
      );
    }

    const inviteReference = await betaInviteReference(inviteId);
    const deviceSession = formatDeviceSession(
      inviteReference,
      activation.sessionId,
      activation.sessionSecret,
    );
    return jsonResponse(
      {
        accountId: activation.accountId,
        deviceSession,
        ...(activation.recoveryCode === null
          ? {}
          : { recoveryCode: activation.recoveryCode }),
      },
      activation.created ? 201 : 200,
    );
  } catch {
    return errorResponse(
      503,
      "beta_identity_unavailable",
      "Beta activation is temporarily unavailable.",
    );
  }
}

async function handleTextRequest(request, env, fetchProvider) {
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

  if (isBetaAiDisabled(env.OVEXIQ_BETA_AI_DISABLED)) {
    return betaDisabledResponse();
  }

  const betaToken = request.headers.get("x-ovexiq-beta-token")?.trim() ?? "";
  const testerId = await findTesterId(env.OVEXIQ_BETA_TOKENS, betaToken);

  if (testerId === null) {
    return errorResponse(401, "unauthorized", "Invalid beta access token.");
  }

  const sessionAuthorizationResponse = await authenticateBudgetedAiSession(
    request,
    env,
  );
  if (sessionAuthorizationResponse !== null) {
    return sessionAuthorizationResponse;
  }

  const rateLimitResponse = await applyRateLimit(env.AI_RATE_LIMITER, testerId);
  if (rateLimitResponse !== null) {
    return rateLimitResponse;
  }

  const parsedRequest = await parseRequest(request);
  if (parsedRequest.response !== null) {
    return parsedRequest.response;
  }

  const dailyQuotaResponse = await applyDailyQuota(
    env.BETA_DAILY_QUOTA,
    testerId,
    "text",
  );
  if (dailyQuotaResponse !== null) {
    return dailyQuotaResponse;
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

  if (isBetaAiDisabled(env.OVEXIQ_BETA_AI_DISABLED)) {
    return betaDisabledResponse();
  }

  const betaToken = request.headers.get("x-ovexiq-beta-token")?.trim() ?? "";
  const testerId = await findTesterId(env.OVEXIQ_BETA_TOKENS, betaToken);

  if (testerId === null) {
    return errorResponse(401, "unauthorized", "Invalid beta access token.");
  }

  const sessionAuthorizationResponse = await authenticateBudgetedAiSession(
    request,
    env,
  );
  if (sessionAuthorizationResponse !== null) {
    return sessionAuthorizationResponse;
  }

  const rateLimitResponse = await applyRateLimit(env.IMAGE_RATE_LIMITER, testerId);
  if (rateLimitResponse !== null) {
    return rateLimitResponse;
  }

  const parsedRequest = await parseImageRequest(request);
  if (parsedRequest.response !== null) {
    return parsedRequest.response;
  }

  const dailyQuotaResponse = await applyDailyQuota(
    env.BETA_DAILY_QUOTA,
    testerId,
    "image",
  );
  if (dailyQuotaResponse !== null) {
    return dailyQuotaResponse;
  }

  return callOpenAiImage(parsedRequest.value, env, fetchProvider);
}

async function handleSpeechRequest(request, env, fetchProvider) {
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

  if (isBetaAiDisabled(env.OVEXIQ_BETA_AI_DISABLED)) {
    return betaDisabledResponse();
  }

  const betaToken = request.headers.get("x-ovexiq-beta-token")?.trim() ?? "";
  const testerId = await findTesterId(env.OVEXIQ_BETA_TOKENS, betaToken);
  if (testerId === null) {
    return errorResponse(401, "unauthorized", "Invalid beta access token.");
  }

  const sessionAuthorizationResponse = await authenticateBudgetedAiSession(
    request,
    env,
  );
  if (sessionAuthorizationResponse !== null) {
    return sessionAuthorizationResponse;
  }

  const rateLimitResponse = await applyRateLimit(env.AI_RATE_LIMITER, testerId);
  if (rateLimitResponse !== null) {
    return rateLimitResponse;
  }

  const parsedRequest = await parseSpeechRequest(request);
  if (parsedRequest.response !== null) {
    return parsedRequest.response;
  }

  const dailyQuotaResponse = await applyDailyQuota(
    env.BETA_DAILY_QUOTA,
    testerId,
    "speech",
  );
  if (dailyQuotaResponse !== null) {
    return dailyQuotaResponse;
  }

  return callOpenAiSpeech(parsedRequest.value, env, fetchProvider);
}

async function handleVideoEditPlanRequest(request) {
  if (request.method !== "POST") {
    return errorResponse(405, "method_not_allowed", "Use POST for this endpoint.", {
      Allow: "POST",
    });
  }

  return betaVideoUnavailableResponse();
}

async function handleVideoTranscriptionRequest(request) {
  if (request.method !== "POST") {
    return errorResponse(405, "method_not_allowed", "Use POST for this endpoint.", {
      Allow: "POST",
    });
  }

  return betaVideoUnavailableResponse();
}

/// A single durable coordination point for the deliberately small beta caps.
/// It persists an allowed request before the Worker contacts a provider.
export class BetaDailyQuota extends DurableObject {
  async consume(testerId, requestType, now = Date.now()) {
    const limits = DAILY_QUOTA_LIMITS[requestType];
    if (
      limits === undefined ||
      typeof testerId !== "string" ||
      testerId.length === 0
    ) {
      return { allowed: false };
    }

    const day = utcDay(now);
    return this.ctx.storage.transaction(async (storage) => {
      const storedState = await storage.get(DAILY_QUOTA_STATE_KEY);
      const state = normalizeDailyQuotaStateForDay(storedState, day)
        ?? createDailyQuotaState(day);
      const testerIndex = state.testers.findIndex((tester) => tester.id === testerId);
      const testerUsage =
        testerIndex === -1
          ? { id: testerId, text: 0, image: 0, speech: 0 }
          : state.testers[testerIndex];

      if (
        state.totals[requestType] >= limits.global ||
        testerUsage[requestType] >= limits.perTester
      ) {
        return { allowed: false };
      }

      const nextTesterUsage = {
        ...testerUsage,
        [requestType]: testerUsage[requestType] + 1,
      };
      const nextTesters = [...state.testers];
      if (testerIndex === -1) {
        nextTesters.push(nextTesterUsage);
      } else {
        nextTesters[testerIndex] = nextTesterUsage;
      }

      await storage.put(DAILY_QUOTA_STATE_KEY, {
        ...state,
        day,
        totals: {
          ...state.totals,
          [requestType]: state.totals[requestType] + 1,
        },
        testers: nextTesters,
      });

      return { allowed: true };
    });
  }
}

/// One durable account per configured invite. The Worker never receives an
/// account ID from a client request; it reaches this object only after the
/// invite or device-session credential has been verified.
export class BetaAccount extends DurableObject {
  async activate({ inviteId, activationId }) {
    if (!isValidActivationId(activationId) || typeof inviteId !== "string" || inviteId.length === 0) {
      throw new Error("invalid activation");
    }

    const signingKey = configuredValue(this.env.OVEXIQ_SESSION_SIGNING_KEY);
    if (signingKey.length < 32) {
      throw new Error("identity signing key unavailable");
    }

    return this.ctx.storage.transaction(async (storage) => {
      const existing = await storage.get(BETA_ACCOUNT_STATE_KEY);
      const state = isBetaAccountState(existing) ? existing : null;
      if (state?.status === "disabled") {
        return { status: "disabled" };
      }

      const created = state === null;
      const newAccount = created ? await createBetaAccountState(inviteId) : null;
      const recoveryCode = newAccount?.recoveryCode ?? null;
      const account = state ?? {
        accountId: newAccount.accountId,
        status: newAccount.status,
        createdAt: newAccount.createdAt,
        inviteId: newAccount.inviteId,
        recoveryVerifier: newAccount.recoveryVerifier,
        sessions: newAccount.sessions,
      };
      const sessionIndex = account.sessions.findIndex(
        (session) => session.activationId === activationId,
      );
      if (sessionIndex !== -1 && account.sessions[sessionIndex].status === "revoked") {
        return { status: "revoked" };
      }
      const sessionMaterial = await deriveSessionMaterial(
        signingKey,
        account.accountId,
        activationId,
      );
      const session = sessionIndex === -1
        ? {
            sessionId: sessionMaterial.sessionId,
            activationId,
            verifier: await sha256Base64Url(sessionMaterial.sessionSecret),
            status: "active",
            createdAt: new Date().toISOString(),
            lastSeenAt: null,
            revokedAt: null,
          }
        : {
            ...account.sessions[sessionIndex],
            verifier: await sha256Base64Url(sessionMaterial.sessionSecret),
          };
      const sessions = [...account.sessions];
      if (sessionIndex === -1) {
        sessions.push(session);
      } else {
        sessions[sessionIndex] = session;
      }

      const nextState = { ...account, sessions };
      await storage.put(BETA_ACCOUNT_STATE_KEY, nextState);
      return {
        status: "active",
        created,
        accountId: nextState.accountId,
        sessionId: session.sessionId,
        sessionSecret: sessionMaterial.sessionSecret,
        recoveryCode,
      };
    });
  }

  async authenticateSession({ sessionId, sessionSecret }) {
    if (!isValidSessionId(sessionId) || !isValidSessionSecret(sessionSecret)) {
      return null;
    }

    return this.ctx.storage.transaction(async (storage) => {
      const state = await storage.get(BETA_ACCOUNT_STATE_KEY);
      if (!isBetaAccountState(state) || state.status !== "active") {
        return null;
      }
      const sessionIndex = state.sessions.findIndex((session) => session.sessionId === sessionId);
      if (sessionIndex === -1) {
        return null;
      }
      const session = state.sessions[sessionIndex];
      if (session.status !== "active") {
        return null;
      }
      const verifier = await sha256Base64Url(sessionSecret);
      if (!await timingSafeTokenEquals(session.verifier, verifier)) {
        return null;
      }

      const sessions = [...state.sessions];
      sessions[sessionIndex] = { ...session, lastSeenAt: new Date().toISOString() };
      await storage.put(BETA_ACCOUNT_STATE_KEY, { ...state, sessions });
      return { accountId: state.accountId, sessionId };
    });
  }

  /// Reserved for an authenticated beta-admin operation. There is deliberately
  /// no public client revocation endpoint in this identity-only task.
  async revokeSession(sessionId) {
    if (!isValidSessionId(sessionId)) {
      return { revoked: false };
    }

    return this.ctx.storage.transaction(async (storage) => {
      const state = await storage.get(BETA_ACCOUNT_STATE_KEY);
      if (!isBetaAccountState(state)) {
        return { revoked: false };
      }
      const sessionIndex = state.sessions.findIndex((session) => session.sessionId === sessionId);
      if (sessionIndex === -1 || state.sessions[sessionIndex].status !== "active") {
        return { revoked: false };
      }
      const sessions = [...state.sessions];
      sessions[sessionIndex] = {
        ...sessions[sessionIndex],
        status: "revoked",
        revokedAt: new Date().toISOString(),
      };
      await storage.put(BETA_ACCOUNT_STATE_KEY, { ...state, sessions });
      return { revoked: true };
    });
  }
}

/// Resolves the server-owned account from an opaque device credential. Future
/// wallet endpoints should call this boundary and must never accept accountId
/// in a request body as proof of ownership.
export async function authenticateBetaDeviceSession(env, presentedSession) {
  const parsedSession = parseDeviceSession(presentedSession);
  if (parsedSession === null) {
    return null;
  }

  const inviteId = await findInviteIdByReference(
    env.OVEXIQ_BETA_INVITES,
    parsedSession.inviteReference,
  );
  if (inviteId === null) {
    return null;
  }
  const accounts = env.BETA_ACCOUNTS;
  if (accounts === null || typeof accounts?.getByName !== "function") {
    return null;
  }

  try {
    const account = accounts.getByName(betaAccountObjectName(inviteId));
    const authenticated = await account.authenticateSession({
      sessionId: parsedSession.sessionId,
      sessionSecret: parsedSession.sessionSecret,
    });
    return authenticated?.accountId ? authenticated : null;
  } catch {
    return null;
  }
}

/// Ensures a budgeted AI request comes from an active, server-authenticated
/// beta installation. Account ownership is derived only from the opaque
/// session; no client-supplied account identifier is accepted here.
async function authenticateBudgetedAiSession(request, env) {
  const authenticated = await authenticateBetaDeviceSession(
    env,
    request.headers.get(DEVICE_SESSION_HEADER) ?? "",
  );
  if (authenticated !== null) {
    return null;
  }

  return errorResponse(
    401,
    "unauthorized",
    "Beta access is not authorized.",
  );
}

async function findTesterId(configuredTokens, presentedToken) {
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
      await timingSafeTokenEquals(token, presentedToken)
    ) {
      return testerId.slice(0, 64);
    }
  }

  return null;
}

async function findInviteId(configuredInvites, presentedInviteCode) {
  const invites = parseConfiguredCredentialMap(configuredInvites);
  if (invites === null || typeof presentedInviteCode !== "string") {
    return null;
  }

  for (const [inviteId, inviteCode] of Object.entries(invites)) {
    if (
      inviteId.trim().length > 0 &&
      typeof inviteCode === "string" &&
      inviteCode.length > 0 &&
      await timingSafeTokenEquals(inviteCode, presentedInviteCode)
    ) {
      return inviteId.slice(0, 64);
    }
  }
  return null;
}

async function findInviteIdByReference(configuredInvites, inviteReference) {
  const invites = parseConfiguredCredentialMap(configuredInvites);
  if (invites === null || !isOpaqueSegment(inviteReference, 24, 64)) {
    return null;
  }

  for (const inviteId of Object.keys(invites)) {
    const expectedReference = await betaInviteReference(inviteId);
    if (await timingSafeTokenEquals(expectedReference, inviteReference)) {
      return inviteId.slice(0, 64);
    }
  }
  return null;
}

function parseConfiguredCredentialMap(value) {
  if (typeof value !== "string" || value.length === 0) {
    return null;
  }
  try {
    const parsed = JSON.parse(value);
    return parsed !== null && typeof parsed === "object" && !Array.isArray(parsed)
      ? parsed
      : null;
  } catch {
    return null;
  }
}

function betaAccountObjectName(inviteId) {
  return `${BETA_ACCOUNT_OBJECT_PREFIX}${inviteId}`;
}

async function betaInviteReference(inviteId) {
  return (await sha256Base64Url(`invite-reference:${inviteId}`)).slice(0, 32);
}

function formatDeviceSession(inviteReference, sessionId, sessionSecret) {
  return `ovs1.${inviteReference}.${sessionId}.${sessionSecret}`;
}

function parseDeviceSession(value) {
  if (typeof value !== "string" || value.length > 512) {
    return null;
  }
  const [version, inviteReference, sessionId, sessionSecret, ...extra] = value.trim().split(".");
  if (
    extra.length > 0 ||
    version !== "ovs1" ||
    !isOpaqueSegment(inviteReference, 24, 64) ||
    !isValidSessionId(sessionId) ||
    !isValidSessionSecret(sessionSecret)
  ) {
    return null;
  }
  return { inviteReference, sessionId, sessionSecret };
}

function isValidActivationResult(value) {
  return (
    value !== null &&
    typeof value === "object" &&
    value.status === "active" &&
    typeof value.created === "boolean" &&
    isValidAccountId(value.accountId) &&
    isValidSessionId(value.sessionId) &&
    isValidSessionSecret(value.sessionSecret) &&
    (value.recoveryCode === null || isValidRecoveryCode(value.recoveryCode))
  );
}

async function createBetaAccountState(inviteId) {
  const recoveryCode = `orc1_${randomBase64Url(24)}`;
  return {
    accountId: `acct_${crypto.randomUUID()}`,
    status: "active",
    createdAt: new Date().toISOString(),
    inviteId,
    recoveryVerifier: await sha256Base64Url(recoveryCode),
    sessions: [],
    recoveryCode,
  };
}

async function deriveSessionMaterial(signingKey, accountId, activationId) {
  const sessionId = `sess_${(await hmacSha256Base64Url(
    signingKey,
    `session-id:${accountId}:${activationId}`,
  )).slice(0, 32)}`;
  const sessionSecret = await hmacSha256Base64Url(
    signingKey,
    `session-secret:${accountId}:${activationId}`,
  );
  return { sessionId, sessionSecret };
}

function isBetaAccountState(value) {
  return (
    value !== null &&
    typeof value === "object" &&
    !Array.isArray(value) &&
    isValidAccountId(value.accountId) &&
    (value.status === "active" || value.status === "disabled") &&
    typeof value.createdAt === "string" &&
    typeof value.inviteId === "string" &&
    isOpaqueSegment(value.recoveryVerifier, 32, 64) &&
    Array.isArray(value.sessions) &&
    value.sessions.every(isBetaDeviceSessionState)
  );
}

function isBetaDeviceSessionState(value) {
  return (
    value !== null &&
    typeof value === "object" &&
    !Array.isArray(value) &&
    isValidSessionId(value.sessionId) &&
    isValidActivationId(value.activationId) &&
    isOpaqueSegment(value.verifier, 32, 64) &&
    (value.status === "active" || value.status === "revoked") &&
    typeof value.createdAt === "string" &&
    (value.lastSeenAt === null || typeof value.lastSeenAt === "string") &&
    (value.revokedAt === null || typeof value.revokedAt === "string")
  );
}

function isValidAccountId(value) {
  return typeof value === "string" && /^acct_[0-9a-f-]{36}$/.test(value);
}

function isValidActivationId(value) {
  return isOpaqueSegment(value, MIN_ACTIVATION_ID_CHARS, MAX_ACTIVATION_ID_CHARS);
}

function isValidSessionId(value) {
  return typeof value === "string" && /^sess_[A-Za-z0-9_-]{32}$/.test(value);
}

function isValidSessionSecret(value) {
  return isOpaqueSegment(value, 43, 64);
}

function isValidRecoveryCode(value) {
  return typeof value === "string" && /^orc1_[A-Za-z0-9_-]{32}$/.test(value);
}

function isOpaqueSegment(value, minimumLength, maximumLength) {
  return (
    typeof value === "string" &&
    value.length >= minimumLength &&
    value.length <= maximumLength &&
    /^[A-Za-z0-9_-]+$/.test(value)
  );
}

async function sha256Base64Url(value) {
  const bytes = new TextEncoder().encode(value);
  return bytesToBase64Url(new Uint8Array(await crypto.subtle.digest("SHA-256", bytes)));
}

async function hmacSha256Base64Url(key, value) {
  const encoder = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    encoder.encode(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return bytesToBase64Url(new Uint8Array(await crypto.subtle.sign("HMAC", cryptoKey, encoder.encode(value))));
}

function randomBase64Url(length) {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return bytesToBase64Url(bytes);
}

function bytesToBase64Url(bytes) {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/u, "");
}

function isBetaAiDisabled(value) {
  return ["1", "true", "yes", "on"].includes(configuredValue(value).toLowerCase());
}

function betaDisabledResponse() {
  return errorResponse(
    503,
    "beta_temporarily_unavailable",
    "Ovexiq AI is temporarily unavailable. Please try again later.",
  );
}

function betaVideoUnavailableResponse() {
  return errorResponse(
    503,
    "beta_video_unavailable",
    "Video features are not available in this beta.",
  );
}

function timingSafeTokenEquals(expectedToken, presentedToken) {
  const encoder = new TextEncoder();
  const expected = encoder.encode(expectedToken);
  const presented = encoder.encode(presentedToken);
  const lengthsMatch = expected.byteLength === presented.byteLength;

  if (typeof crypto.subtle.timingSafeEqual === "function") {
    return lengthsMatch
      ? crypto.subtle.timingSafeEqual(expected, presented)
      : !crypto.subtle.timingSafeEqual(presented, presented);
  }

  const maxLength = Math.max(expected.byteLength, presented.byteLength);
  let difference = expected.byteLength ^ presented.byteLength;
  for (let index = 0; index < maxLength; index += 1) {
    difference |= (expected[index] ?? 0) ^ (presented[index] ?? 0);
  }
  return difference === 0;
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

async function applyDailyQuota(quotaNamespace, testerId, requestType) {
  if (quotaNamespace === null || typeof quotaNamespace?.getByName !== "function") {
    return errorResponse(
      503,
      "beta_limit_unavailable",
      "Ovexiq AI is temporarily unavailable.",
    );
  }

  try {
    const quota = quotaNamespace.getByName(DAILY_QUOTA_OBJECT_NAME);
    const result = await quota.consume(testerId, requestType);
    if (result?.allowed === true) {
      return null;
    }
    if (result?.allowed === false) {
      return errorResponse(
        429,
        "beta_limit_reached",
        "Beta request limit reached. Try again tomorrow.",
        { "Retry-After": String(secondsUntilNextUtcDay()) },
      );
    }
  } catch {
    // The quota service is part of the spend boundary, so fail closed.
  }

  return errorResponse(
    503,
    "beta_limit_unavailable",
    "Ovexiq AI is temporarily unavailable.",
  );
}

function createDailyQuotaState(day) {
  return {
    day,
    totals: { text: 0, image: 0, speech: 0 },
    testers: [],
  };
}

export function normalizeDailyQuotaStateForDay(value, day) {
  if (!isDailyQuotaStateForDay(value, day)) {
    return null;
  }

  return {
    ...value,
    totals: {
      ...value.totals,
      speech: value.totals.speech ?? 0,
    },
    testers: value.testers.map((tester) => ({
      ...tester,
      speech: tester.speech ?? 0,
    })),
  };
}

function isDailyQuotaStateForDay(value, day) {
  return (
    value !== null &&
    typeof value === "object" &&
    !Array.isArray(value) &&
    value.day === day &&
    value.totals !== null &&
    typeof value.totals === "object" &&
    !Array.isArray(value.totals) &&
    Array.isArray(value.testers) &&
    Number.isInteger(value.totals.text) &&
    Number.isInteger(value.totals.image) &&
    (value.totals.speech === undefined || Number.isInteger(value.totals.speech)) &&
    value.testers.every(isDailyQuotaTester)
  );
}

function isDailyQuotaTester(value) {
  return (
    value !== null &&
    typeof value === "object" &&
    !Array.isArray(value) &&
    typeof value.id === "string" &&
    Number.isInteger(value.text) &&
    Number.isInteger(value.image) &&
    (value.speech === undefined || Number.isInteger(value.speech))
  );
}

function utcDay(now = Date.now()) {
  return new Date(now).toISOString().slice(0, 10);
}

function secondsUntilNextUtcDay() {
  const now = new Date();
  const nextDay = Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate() + 1,
  );
  return Math.max(1, Math.ceil((nextDay - now.getTime()) / 1_000));
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

  let responseLanguage = "auto";
  if (body.response_language !== undefined) {
    if (
      typeof body.response_language !== "string" ||
      !RESPONSE_LANGUAGES.has(body.response_language)
    ) {
      return failure(
        400,
        "invalid_response_language",
        "response_language must be my, en, or auto.",
      );
    }
    responseLanguage = body.response_language;
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
    value: { messages, temperature, maxTokens, responseLanguage, metadata },
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

async function parseBetaActivationRequest(request) {
  const bodyResult = await parseJsonBody(request);
  if (bodyResult.response !== null) {
    return bodyResult;
  }

  const body = bodyResult.value;
  if (
    !hasOnlyKeys(body, ["inviteCode", "activationId"]) ||
    typeof body.inviteCode !== "string" ||
    typeof body.activationId !== "string"
  ) {
    return failure(400, "invalid_activation_request", "A beta invite is required.");
  }

  const inviteCode = body.inviteCode.trim();
  const activationId = body.activationId.trim();
  if (
    inviteCode.length === 0 ||
    inviteCode.length > MAX_BETA_INVITE_CODE_CHARS ||
    !isValidActivationId(activationId)
  ) {
    return failure(400, "invalid_activation_request", "A beta invite is required.");
  }

  return { response: null, value: { inviteCode, activationId } };
}

async function parseSpeechRequest(request) {
  const bodyResult = await parseJsonBody(request);
  if (bodyResult.response !== null) {
    return bodyResult;
  }

  const body = bodyResult.value;
  if (!hasOnlyKeys(body, ["text"]) || typeof body.text !== "string") {
    return failure(400, "invalid_speech_request", "Narration text is required.");
  }

  const text = body.text.trim();
  if (text.length === 0) {
    return failure(400, "empty_speech_text", "Narration text is required.");
  }
  if (text.length > MAX_NARRATION_CHARS) {
    return failure(413, "speech_text_too_large", "Narration text is too large.");
  }

  return { response: null, value: { text } };
}

async function parseVideoTranscriptionRequest(request) {
  let formData;
  try {
    formData = await request.formData();
  } catch {
    return failure(400, "invalid_audio_request", "Audio request is invalid.");
  }
  const entries = Array.from(formData.entries());
  if (entries.length !== 2 ||
      !entries.every(([key]) => key === "clipId" || key === "audio")) {
    return failure(400, "invalid_audio_request", "Audio request is invalid.");
  }

  const clipIdValue = formData.get("clipId");
  const audio = formData.get("audio");
  if (typeof clipIdValue !== "string" ||
      clipIdValue.trim().length === 0 ||
      clipIdValue.trim().length > MAX_TRANSCRIPTION_CLIP_ID_CHARS ||
      !isUploadedFile(audio) ||
      audio.size <= 0 ||
      audio.size > MAX_TRANSCRIPTION_AUDIO_BYTES ||
      !ALLOWED_TRANSCRIPTION_AUDIO_TYPES.has(audio.type.toLowerCase())) {
    return failure(400, "invalid_audio_request", "Audio request is invalid.");
  }

  return {
    response: null,
    value: {
      clipId: clipIdValue.trim(),
      audio,
    },
  };
}

async function parseVideoEditPlanRequest(request) {
  const bodyResult = await parseJsonBody(request);
  if (bodyResult.response !== null) {
    return bodyResult;
  }

  const body = bodyResult.value;
  if (!hasOnlyKeys(body, ["instruction", "clips", "output"])) {
    return failure(400, "invalid_video_edit_request", "Video edit request is invalid.");
  }
  if (typeof body.instruction !== "string") {
    return failure(400, "invalid_video_edit_instruction", "A video edit instruction is required.");
  }
  const instruction = body.instruction.trim();
  if (instruction.length === 0) {
    return failure(400, "empty_video_edit_instruction", "A video edit instruction is required.");
  }
  if (instruction.length > MAX_VIDEO_EDIT_INSTRUCTION_CHARS) {
    return failure(413, "video_edit_instruction_too_large", "Video edit instruction is too large.");
  }
  if (!Array.isArray(body.clips) ||
      body.clips.length < MIN_VIDEO_CLIPS ||
      body.clips.length > MAX_VIDEO_CLIPS ||
      !isObject(body.output) ||
      !hasOnlyKeys(body.output, ["targetDurationMs", "verticalSocialVideo"]) ||
      typeof body.output.verticalSocialVideo !== "boolean") {
    return failure(400, "invalid_video_edit_request", "Video edit request is invalid.");
  }

  let targetDurationMs;
  if (body.output.targetDurationMs !== undefined) {
    if (!isPositiveInteger(body.output.targetDurationMs) ||
        body.output.targetDurationMs > MAX_VIDEO_TARGET_DURATION_MS) {
      return failure(400, "invalid_video_target_duration", "Video edit request is invalid.");
    }
    targetDurationMs = body.output.targetDurationMs;
  }

  const seenClipIds = new Set();
  const clips = [];
  let totalAnalysisBytes = 0;
  let totalAnalysisSegments = 0;
  let totalTranscriptChars = 0;
  for (const clip of body.clips) {
    if (!isObject(clip) ||
        !hasOnlyKeys(clip, [
          "clipId",
          "durationMs",
          "width",
          "height",
          "orientation",
          "hasAudio",
          "fileSizeBytes",
          "frameRate",
          "contentAnalysis",
        ]) ||
        typeof clip.clipId !== "string" ||
        clip.clipId.trim().length === 0 ||
        clip.clipId.trim().length > MAX_VIDEO_CLIP_ID_CHARS ||
        !seenClipIds.add(clip.clipId.trim()) ||
        !isPositiveInteger(clip.durationMs) ||
        clip.durationMs > MAX_VIDEO_DURATION_MS ||
        !isPositiveInteger(clip.width) ||
        clip.width > MAX_VIDEO_DIMENSION ||
        !isPositiveInteger(clip.height) ||
        clip.height > MAX_VIDEO_DIMENSION ||
        !ALLOWED_VIDEO_ORIENTATIONS.has(clip.orientation) ||
        typeof clip.hasAudio !== "boolean" ||
        !isPositiveInteger(clip.fileSizeBytes) ||
        clip.fileSizeBytes > MAX_VIDEO_FILE_SIZE_BYTES ||
        (clip.frameRate !== undefined &&
          (!isFiniteNumber(clip.frameRate) ||
            clip.frameRate <= 0 ||
            clip.frameRate > MAX_VIDEO_FRAME_RATE))) {
      return failure(400, "invalid_video_clip", "Video edit request is invalid.");
    }

    const analysisResult = parseVideoClipContentAnalysis(
      clip.contentAnalysis,
      clip.durationMs,
    );
    if (!analysisResult.valid ||
        totalAnalysisBytes + analysisResult.byteSize > MAX_VIDEO_CONTENT_ANALYSIS_BYTES ||
        totalAnalysisSegments + analysisResult.segmentCount > MAX_VIDEO_ANALYSIS_SEGMENTS_TOTAL ||
        totalTranscriptChars + analysisResult.transcriptChars > MAX_VIDEO_TRANSCRIPT_CHARS_TOTAL) {
      return failure(400, "invalid_video_content_analysis", "Video edit request is invalid.");
    }
    totalAnalysisBytes += analysisResult.byteSize;
    totalAnalysisSegments += analysisResult.segmentCount;
    totalTranscriptChars += analysisResult.transcriptChars;

    clips.push({
      clipId: clip.clipId.trim(),
      durationMs: clip.durationMs,
      width: clip.width,
      height: clip.height,
      orientation: clip.orientation,
      hasAudio: clip.hasAudio,
      fileSizeBytes: clip.fileSizeBytes,
      ...(clip.frameRate !== undefined ? { frameRate: clip.frameRate } : {}),
      ...(analysisResult.value !== undefined
        ? { contentAnalysis: analysisResult.value }
        : {}),
    });
  }

  return {
    response: null,
    value: {
      instruction,
      clips,
      output: {
        verticalSocialVideo: body.output.verticalSocialVideo,
        ...(targetDurationMs !== undefined ? { targetDurationMs } : {}),
      },
    },
  };
}

function parseVideoClipContentAnalysis(contentAnalysis, durationMs) {
  const empty = {
    valid: true,
    value: undefined,
    byteSize: 0,
    segmentCount: 0,
    transcriptChars: 0,
  };
  if (contentAnalysis === undefined) {
    return empty;
  }
  if (!isObject(contentAnalysis) ||
      !hasOnlyKeys(contentAnalysis, [
        "analysisVersion",
        "language",
        "speechPresent",
        "transcriptSegments",
        "sceneSegments",
        "audioActivity",
      ]) ||
      typeof contentAnalysis.analysisVersion !== "string") {
    return { ...empty, valid: false };
  }

  const analysisVersion = contentAnalysis.analysisVersion.trim();
  if (analysisVersion.length === 0 ||
      analysisVersion.length > MAX_VIDEO_ANALYSIS_VERSION_CHARS ||
      (contentAnalysis.language !== undefined &&
        (typeof contentAnalysis.language !== "string" ||
          contentAnalysis.language.trim().length === 0 ||
          contentAnalysis.language.trim().length > 64)) ||
      (contentAnalysis.speechPresent !== undefined &&
        typeof contentAnalysis.speechPresent !== "boolean")) {
    return { ...empty, valid: false };
  }

  const transcriptResult = parseTranscriptSegments(
    contentAnalysis.transcriptSegments,
    durationMs,
  );
  const sceneResult = parseSceneSegments(contentAnalysis.sceneSegments, durationMs);
  const audioResult = parseAudioActivity(contentAnalysis.audioActivity, durationMs);
  if (!transcriptResult.valid || !sceneResult.valid || !audioResult.valid) {
    return { ...empty, valid: false };
  }

  const value = {
    analysisVersion,
    ...(contentAnalysis.language !== undefined
      ? { language: contentAnalysis.language.trim() }
      : {}),
    ...(contentAnalysis.speechPresent !== undefined
      ? { speechPresent: contentAnalysis.speechPresent }
      : {}),
    ...(transcriptResult.value.length > 0
      ? { transcriptSegments: transcriptResult.value }
      : {}),
    ...(sceneResult.value.length > 0 ? { sceneSegments: sceneResult.value } : {}),
    ...(audioResult.value.length > 0 ? { audioActivity: audioResult.value } : {}),
  };
  return {
    valid: new TextEncoder().encode(JSON.stringify(value)).byteLength <=
      MAX_VIDEO_CONTENT_ANALYSIS_BYTES,
    value,
    byteSize: new TextEncoder().encode(JSON.stringify(value)).byteLength,
    segmentCount:
      transcriptResult.value.length + sceneResult.value.length + audioResult.value.length,
    transcriptChars: transcriptResult.textChars,
  };
}

function parseTranscriptSegments(value, durationMs) {
  if (value === undefined) return { valid: true, value: [], textChars: 0 };
  if (!Array.isArray(value) || value.length > MAX_VIDEO_TRANSCRIPT_SEGMENTS_PER_CLIP) {
    return { valid: false, value: [], textChars: 0 };
  }
  const segments = [];
  let textChars = 0;
  for (const segment of value) {
    if (!isObject(segment) ||
        !hasOnlyKeys(segment, ["startMs", "endMs", "text"]) ||
        !isValidTimestampRange(segment.startMs, segment.endMs, durationMs) ||
        typeof segment.text !== "string") {
      return { valid: false, value: [], textChars: 0 };
    }
    const text = segment.text.trim();
    if (text.length === 0 || text.length > MAX_VIDEO_TRANSCRIPT_SEGMENT_CHARS) {
      return { valid: false, value: [], textChars: 0 };
    }
    textChars += text.length;
    segments.push({ startMs: segment.startMs, endMs: segment.endMs, text });
  }
  return { valid: true, value: segments, textChars };
}

function parseSceneSegments(value, durationMs) {
  if (value === undefined) return { valid: true, value: [] };
  if (!Array.isArray(value) || value.length > MAX_VIDEO_SCENE_SEGMENTS_PER_CLIP) {
    return { valid: false, value: [] };
  }
  const segments = [];
  for (const segment of value) {
    if (!isObject(segment) ||
        !hasOnlyKeys(segment, ["startMs", "endMs", "label"]) ||
        !isValidTimestampRange(segment.startMs, segment.endMs, durationMs) ||
        (segment.label !== undefined && typeof segment.label !== "string")) {
      return { valid: false, value: [] };
    }
    const label = segment.label?.trim();
    if (label !== undefined &&
        (label.length === 0 || label.length > MAX_VIDEO_SCENE_LABEL_CHARS)) {
      return { valid: false, value: [] };
    }
    segments.push({
      startMs: segment.startMs,
      endMs: segment.endMs,
      ...(label !== undefined ? { label } : {}),
    });
  }
  return { valid: true, value: segments };
}

function parseAudioActivity(value, durationMs) {
  if (value === undefined) return { valid: true, value: [] };
  if (!Array.isArray(value) || value.length > MAX_VIDEO_AUDIO_ACTIVITY_SEGMENTS_PER_CLIP) {
    return { valid: false, value: [] };
  }
  const segments = [];
  for (const segment of value) {
    if (!isObject(segment) ||
        !hasOnlyKeys(segment, ["startMs", "endMs"]) ||
        !isValidTimestampRange(segment.startMs, segment.endMs, durationMs)) {
      return { valid: false, value: [] };
    }
    segments.push({ startMs: segment.startMs, endMs: segment.endMs });
  }
  return { valid: true, value: segments };
}

function isValidTimestampRange(startMs, endMs, durationMs) {
  return Number.isInteger(startMs) &&
    Number.isInteger(endMs) &&
    startMs >= 0 &&
    endMs > startMs &&
    endMs <= durationMs;
}

async function parseJsonBody(request) {
  let rawBody;
  try {
    rawBody = await request.text();
  } catch {
    return failure(400, "invalid_json", "Request body must be valid JSON.");
  }
  if (new TextEncoder().encode(rawBody).byteLength > MAX_BODY_BYTES) {
    return failure(413, "payload_too_large", "Request payload is too large.");
  }
  try {
    const value = JSON.parse(rawBody);
    if (!isObject(value)) {
      return failure(400, "invalid_request", "Request body must be a JSON object.");
    }
    return { response: null, value };
  } catch {
    return failure(400, "invalid_json", "Request body must be valid JSON.");
  }
}

async function callProvider(input, env, fetchProvider) {
  const startedAt = Date.now();
  let routeClass;
  let providerResult;
  let fallbackAttempted = false;
  let selectedModel;
  const correlationId = input.responseLanguage === "my"
    ? createSafeCorrelationId()
    : null;

  if (input.responseLanguage === "my") {
    routeClass = "burmese_strong";
    selectedModel = BURMESE_STRONG_MODEL;
    providerResult = await callBurmeseStrongProvider(input, env, fetchProvider);
  } else {
    routeClass = "standard";
    selectedModel = configuredValue(env.OPENAI_MODEL) || "standard";
    const standardResult = await callStandardProvider(input, env, fetchProvider);
    providerResult = standardResult.result;
    fallbackAttempted = standardResult.fallbackAttempted;
  }

  logProviderRouteTelemetry({
    routeClass,
    providerResult,
    fallbackAttempted,
    startedAt,
    selectedModel,
    responseLanguage: input.responseLanguage,
    correlationId,
  });

  const response = providerResult.response ?? providerResult.failureResponse;
  return correlationId === null
    ? response
    : withSafeCorrelationId(response, correlationId);
}

async function callStandardProvider(input, env, fetchProvider) {
  const openAiResult = await callOpenAi(input, env, fetchProvider);
  if (openAiResult.response !== null) {
    return { result: openAiResult, fallbackAttempted: false };
  }

  if (!openAiResult.canFallback) {
    return { result: openAiResult, fallbackAttempted: false };
  }

  const openRouterResult = await callOpenRouter(input, env, fetchProvider);
  return {
    result: openRouterResult ?? openAiResult,
    fallbackAttempted: openRouterResult !== null,
  };
}

async function callBurmeseStrongProvider(input, env, fetchProvider) {
  const providerApiKey = configuredValue(env.OPENROUTER_API_KEY);
  const telemetry = {
    providerTransport: "openrouter_chat_completions",
    timeout: false,
  };

  if (providerApiKey.length === 0) {
    return providerFailure(
      503,
      "provider_unavailable",
      "Ovexiq AI is temporarily unavailable.",
      false,
      telemetry,
    );
  }

  // This intentionally mirrors the independently verified OpenRouter Chat
  // Completions request shape. Do not add temperature or reasoning fields:
  // neither is required for this strong Burmese route.
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
        model: BURMESE_STRONG_MODEL,
        messages: input.messages,
        max_tokens: effectiveOutputTokenLimit(input, MAX_BURMESE_OUTPUT_TOKENS),
      }),
    },
    BURMESE_STRONG_TIMEOUT_MS,
  );

  if (fetchResult.error !== null) {
    if (fetchResult.timedOut) {
      return providerFailure(
        504,
        "provider_timeout",
        "Ovexiq AI timed out. Please try again.",
        false,
        { ...telemetry, timeout: true },
      );
    }

    return providerFailure(
      502,
      "provider_transport_failure",
      "Ovexiq AI is temporarily unavailable.",
      false,
      telemetry,
    );
  }

  const providerResponse = fetchResult.response;
  if (!providerResponse.ok) {
    const failureCategory = providerFailureCategoryForStatus(providerResponse.status);
    return providerFailure(
      502,
      failureCategory,
      "Ovexiq AI is temporarily unavailable.",
      false,
      {
        ...telemetry,
        upstreamHttpStatus: providerResponse.status,
        upstreamStatusCategory: providerStatusCategory(providerResponse.status),
      },
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
      false,
      {
        ...telemetry,
        upstreamHttpStatus: providerResponse.status,
        upstreamStatusCategory: providerStatusCategory(providerResponse.status),
      },
    );
  }

  const content = extractOpenRouterOutputText(providerPayload);
  if (content.length === 0) {
    return providerFailure(
      502,
      "empty_provider_response",
      "Ovexiq AI returned an empty response.",
      false,
      {
        ...telemetry,
        upstreamHttpStatus: providerResponse.status,
        upstreamStatusCategory: providerStatusCategory(providerResponse.status),
      },
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
            ...(Number.isInteger(usage.prompt_tokens)
              ? { promptTokens: usage.prompt_tokens }
              : {}),
            ...(Number.isInteger(usage.completion_tokens)
              ? { completionTokens: usage.completion_tokens }
              : {}),
          },
        }
      : {}),
  }, BURMESE_STRONG_MODEL, {
    ...telemetry,
    upstreamHttpStatus: providerResponse.status,
    upstreamStatusCategory: providerStatusCategory(providerResponse.status),
  });
}

async function callOpenAi(input, env, fetchProvider) {
  const model = configuredValue(env.OPENAI_MODEL);
  return callOpenAiModel(input, env, fetchProvider, model);
}

async function callOpenAiModel(input, env, fetchProvider, model, maxOutputTokens) {
  const providerApiKey = configuredValue(env.OPENAI_API_KEY);

  if (providerApiKey.length === 0 || model.length === 0) {
    return providerFailure(503, "provider_unavailable", "Ovexiq AI is temporarily unavailable.");
  }

  const providerBody = {
    model,
    input: input.messages,
    store: false,
    max_output_tokens: effectiveOutputTokenLimit(input, maxOutputTokens),
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
  }, model);
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

async function callOpenAiSpeech(input, env, fetchProvider) {
  const providerApiKey = configuredValue(env.OPENAI_API_KEY);
  if (providerApiKey.length === 0) {
    return errorResponse(
      503,
      "speech_unavailable",
      "Ovexiq narration is temporarily unavailable.",
    );
  }

  const fetchResult = await fetchWithTimeout(
    fetchProvider,
    OPENAI_SPEECH_URL,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${providerApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: OPENAI_SPEECH_MODEL,
        voice: OPENAI_SPEECH_VOICE,
        input: input.text,
        response_format: "mp3",
      }),
    },
    OPENAI_TIMEOUT_MS,
  );

  if (fetchResult.error !== null || !fetchResult.response.ok || fetchResult.response.body === null) {
    return errorResponse(
      fetchResult.timedOut ? 504 : 502,
      "speech_unavailable",
      "Ovexiq narration is temporarily unavailable.",
    );
  }

  const contentType = fetchResult.response.headers.get("content-type")?.toLowerCase() ?? "";
  if (!contentType.startsWith("audio/mpeg")) {
    return errorResponse(
      502,
      "speech_invalid",
      "Ovexiq narration is temporarily unavailable.",
    );
  }

  return new Response(fetchResult.response.body, {
    status: 200,
    headers: {
      "Content-Type": "audio/mpeg",
      "Cache-Control": "no-store",
    },
  });
}

async function callOpenAiVideoTranscription(input, env, fetchProvider) {
  const providerApiKey = configuredValue(env.OPENAI_API_KEY);
  if (providerApiKey.length === 0) {
    return errorResponse(
      503,
      "transcription_unavailable",
      "Ovexiq transcription is temporarily unavailable.",
    );
  }

  const providerForm = new FormData();
  providerForm.append("file", input.audio, `${safeFilePart(input.clipId)}.m4a`);
  providerForm.append("model", OPENAI_TRANSCRIPTION_MODEL);
  providerForm.append("response_format", "verbose_json");
  providerForm.append("timestamp_granularities[]", "segment");

  const fetchResult = await fetchWithTimeout(
    fetchProvider,
    OPENAI_TRANSCRIPTIONS_URL,
    {
      method: "POST",
      headers: { Authorization: `Bearer ${providerApiKey}` },
      body: providerForm,
    },
    OPENAI_TIMEOUT_MS,
  );
  if (fetchResult.error !== null || !fetchResult.response.ok) {
    return errorResponse(
      fetchResult.timedOut ? 504 : 502,
      "transcription_unavailable",
      "Ovexiq transcription is temporarily unavailable.",
    );
  }

  let providerPayload;
  try {
    providerPayload = await fetchResult.response.json();
  } catch {
    return errorResponse(
      502,
      "transcription_invalid",
      "Ovexiq transcription returned an invalid result.",
    );
  }
  const response = mapVideoTranscriptionResponse(input.clipId, providerPayload);
  if (response === null) {
    return errorResponse(
      502,
      "transcription_invalid",
      "Ovexiq transcription returned an invalid result.",
    );
  }
  return jsonResponse(response);
}

async function callOpenAiVideoEditPlan(input, env, fetchProvider) {
  const providerApiKey = configuredValue(env.OPENAI_API_KEY);
  const model = configuredValue(env.OPENAI_MODEL);
  if (providerApiKey.length === 0 || model.length === 0) {
    return errorResponse(
      503,
      "video_edit_plan_unavailable",
      "Ovexiq video planning is temporarily unavailable.",
    );
  }

  const fetchResult = await fetchWithTimeout(
    fetchProvider,
    OPENAI_RESPONSES_URL,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${providerApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        store: false,
        max_output_tokens: 1_200,
        input: [
          { role: "system", content: VIDEO_EDIT_PLAN_INSTRUCTIONS },
          { role: "user", content: JSON.stringify(input) },
        ],
        text: {
          format: {
            type: "json_schema",
            name: "video_edit_plan",
            strict: true,
            schema: VIDEO_EDIT_PLAN_SCHEMA,
          },
        },
      }),
    },
    OPENAI_TIMEOUT_MS,
  );

  if (fetchResult.error !== null || !fetchResult.response.ok) {
    return errorResponse(
      fetchResult.timedOut ? 504 : 502,
      "video_edit_plan_unavailable",
      "Ovexiq video planning is temporarily unavailable.",
    );
  }

  let providerPayload;
  try {
    providerPayload = await fetchResult.response.json();
  } catch {
    return errorResponse(
      502,
      "video_edit_plan_invalid",
      "Ovexiq video planning returned an invalid result.",
    );
  }

  let plan;
  try {
    plan = JSON.parse(extractOutputText(providerPayload));
  } catch {
    return errorResponse(
      502,
      "video_edit_plan_invalid",
      "Ovexiq video planning returned an invalid result.",
    );
  }

  if (!isValidVideoEditPlanResponse(plan, input)) {
    return errorResponse(
      502,
      "video_edit_plan_invalid",
      "Ovexiq video planning returned an invalid result.",
    );
  }

  return jsonResponse(plan);
}

async function callOpenRouter(input, env, fetchProvider) {
  const model = configuredValue(env.OPENROUTER_MODEL);
  if (model.length === 0) {
    return null;
  }

  return callOpenRouterModel(input, env, fetchProvider, model);
}

async function callOpenRouterModel(input, env, fetchProvider, model, provider) {
  const providerApiKey = configuredValue(env.OPENROUTER_API_KEY);
  if (providerApiKey.length === 0) {
    return providerFailure(503, "provider_unavailable", "Ovexiq AI is temporarily unavailable.");
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
        max_tokens: effectiveOutputTokenLimit(input),
        ...(input.temperature !== undefined ? { temperature: input.temperature } : {}),
        ...(provider !== undefined
          ? { provider: { only: [provider], allow_fallbacks: false } }
          : {}),
      }),
    },
    OPENROUTER_TIMEOUT_MS,
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

  const content = extractOpenRouterOutputText(providerPayload);
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
            ...(Number.isInteger(usage.prompt_tokens)
              ? { promptTokens: usage.prompt_tokens }
              : {}),
            ...(Number.isInteger(usage.completion_tokens)
              ? { completionTokens: usage.completion_tokens }
              : {}),
          },
        }
      : {}),
  }, model);
}

function effectiveOutputTokenLimit(input, routeMaximum = MAX_OUTPUT_TOKENS) {
  const requested = input.maxTokens ?? routeMaximum;
  return Math.min(requested, routeMaximum);
}

function logProviderRouteTelemetry({
  routeClass,
  providerResult,
  fallbackAttempted,
  startedAt,
  selectedModel,
  responseLanguage,
  correlationId,
}) {
  const telemetry = providerResult.telemetry ?? {};
  const usage = telemetry.usage ?? {};
  console.info(JSON.stringify({
    event: "ovexiq_ai_route",
    ...(correlationId !== null ? { request_id: correlationId } : {}),
    response_language: responseLanguage,
    route_class: routeClass,
    provider_transport: telemetry.providerTransport ?? null,
    provider_outcome: telemetry.outcome ?? "failure",
    model: telemetry.model ?? selectedModel ?? "unknown",
    fallback_attempted: fallbackAttempted,
    failure_category: telemetry.failureCategory ?? null,
    upstream_http_status: Number.isInteger(telemetry.upstreamHttpStatus)
      ? telemetry.upstreamHttpStatus
      : null,
    upstream_status_category: telemetry.upstreamStatusCategory ?? null,
    timeout: telemetry.timeout === true,
    latency_ms: Math.max(0, Date.now() - startedAt),
    prompt_tokens: Number.isInteger(usage.promptTokens) ? usage.promptTokens : null,
    completion_tokens: Number.isInteger(usage.completionTokens)
      ? usage.completionTokens
      : null,
  }));
}

function providerFailureCategoryForStatus(status) {
  if (status === 429) {
    return "provider_rate_limited";
  }
  if (status >= 500 && status <= 599) {
    return "provider_upstream_5xx";
  }
  if (status >= 400 && status <= 499) {
    return "provider_rejected_4xx";
  }
  return "provider_unexpected_status";
}

function providerStatusCategory(status) {
  if (status === 429) {
    return "429";
  }
  if (status >= 500 && status <= 599) {
    return "5xx";
  }
  if (status >= 400 && status <= 499) {
    return "4xx";
  }
  if (status >= 200 && status <= 299) {
    return "2xx";
  }
  return "other";
}

function createSafeCorrelationId() {
  return crypto.randomUUID();
}

function withSafeCorrelationId(response, correlationId) {
  const headers = new Headers(response.headers);
  headers.set("X-Ovexiq-Request-Id", correlationId);
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
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

function mapVideoTranscriptionResponse(clipId, payload) {
  if (!isObject(payload) || !Array.isArray(payload.segments) ||
      payload.segments.length > MAX_TRANSCRIPTION_SEGMENTS ||
      (payload.language !== undefined && typeof payload.language !== "string")) {
    return null;
  }
  const segments = [];
  let textChars = 0;
  for (const segment of payload.segments) {
    if (!isObject(segment) ||
        !isFiniteNumber(segment.start) ||
        !isFiniteNumber(segment.end) ||
        typeof segment.text !== "string") {
      return null;
    }
    const startMs = Math.round(segment.start * 1_000);
    const endMs = Math.round(segment.end * 1_000);
    const text = segment.text.trim();
    if (startMs < 0 || endMs <= startMs ||
        endMs > MAX_TRANSCRIPTION_DURATION_MS ||
        text.length === 0 || text.length > MAX_TRANSCRIPTION_SEGMENT_CHARS) {
      return null;
    }
    textChars += text.length;
    if (textChars > MAX_TRANSCRIPTION_TEXT_CHARS) {
      return null;
    }
    segments.push({ startMs, endMs, text });
  }
  const language = payload.language?.trim();
  if (language !== undefined && language.length > 64) {
    return null;
  }
  return { clipId, language: language || null, segments };
}

function isUploadedFile(value) {
  return value !== null &&
    typeof value === "object" &&
    typeof value.arrayBuffer === "function" &&
    typeof value.type === "string" &&
    Number.isFinite(value.size);
}

function safeFilePart(value) {
  const safe = String(value).replace(/[^A-Za-z0-9_-]/g, "_");
  return safe.length > 0 ? safe : "clip";
}

function configuredValue(value) {
  return typeof value === "string" ? value.trim() : "";
}

function isValidVideoEditPlanResponse(plan, input) {
  if (!isObject(plan) ||
      !hasOnlyKeys(plan, ["targetDurationMs", "segments"]) ||
      !Array.isArray(plan.segments) ||
      plan.segments.length !== input.clips.length ||
      (plan.targetDurationMs !== null &&
        (!isPositiveInteger(plan.targetDurationMs) ||
          plan.targetDurationMs > MAX_VIDEO_TARGET_DURATION_MS))) {
    return false;
  }
  if (input.output.targetDurationMs !== undefined &&
      plan.targetDurationMs !== input.output.targetDurationMs) {
    return false;
  }

  const clipById = new Map(input.clips.map((clip) => [clip.clipId, clip]));
  const seenIds = new Set();
  const seenOrders = new Set();
  let keptCount = 0;
  let keptDurationMs = 0;
  for (const segment of plan.segments) {
    if (!isObject(segment) ||
        !hasOnlyKeys(segment, ["clipId", "keep", "order", "trimStartMs", "trimEndMs"]) ||
        typeof segment.clipId !== "string" ||
        typeof segment.keep !== "boolean" ||
        !Number.isInteger(segment.order) ||
        segment.order < 0 ||
        segment.order >= input.clips.length ||
        !seenIds.add(segment.clipId) ||
        !seenOrders.add(segment.order)) {
      return false;
    }
    const clip = clipById.get(segment.clipId);
    if (clip === undefined ||
        (segment.trimStartMs !== null && !Number.isInteger(segment.trimStartMs)) ||
        (segment.trimEndMs !== null && !Number.isInteger(segment.trimEndMs))) {
      return false;
    }
    const start = segment.trimStartMs ?? 0;
    const end = segment.trimEndMs ?? clip.durationMs;
    if (start < 0 || end <= start || end > clip.durationMs) {
      return false;
    }
    if (segment.keep) {
      keptCount += 1;
      keptDurationMs += end - start;
    }
  }
  return seenIds.size === input.clips.length &&
    seenOrders.size === input.clips.length &&
    keptCount >= MIN_VIDEO_CLIPS &&
    keptDurationMs > 0 &&
    (plan.targetDurationMs === null ||
      Math.abs(plan.targetDurationMs - keptDurationMs) <= 1_000);
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function hasOnlyKeys(value, allowedKeys) {
  return Object.keys(value).every((key) => allowedKeys.includes(key));
}

function isPositiveInteger(value) {
  return Number.isInteger(value) && value > 0;
}

function isFiniteNumber(value) {
  return typeof value === "number" && Number.isFinite(value);
}

function providerSuccess(response, telemetryModel, telemetryExtras = {}) {
  return {
    response: jsonResponse(response),
    failureResponse: null,
    canFallback: false,
    telemetry: {
      outcome: "success",
      model: typeof response.model === "string" ? response.model : telemetryModel ?? "unknown",
      usage: response.usage ?? null,
      ...telemetryExtras,
    },
  };
}

function providerFailure(status, code, message, canFallback = false, telemetryExtras = {}) {
  return {
    response: null,
    failureResponse: errorResponse(status, code, message),
    canFallback,
    telemetry: {
      outcome: "failure",
      failureCategory: code,
      ...telemetryExtras,
    },
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
