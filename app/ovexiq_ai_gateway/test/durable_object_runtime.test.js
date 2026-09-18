import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { fileURLToPath } from "node:url";
import path from "node:path";

import { createTestHarness, unstable_startWorker } from "wrangler";

const gatewayRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const runtimeConfigPath = path.join(gatewayRoot, "wrangler.runtime-test.jsonc");
const runtimeEnvPath = path.join(gatewayRoot, "test", "runtime.test.env");
const textUrl = "http://runtime-test.invalid/v1/ai/complete";
const imageUrl = "http://runtime-test.invalid/v1/ai/image";
const speechUrl = "http://runtime-test.invalid/v1/ai/speech";
const activationUrl = "http://runtime-test.invalid/v1/beta/activate";
const videoEditPlanUrl = "http://runtime-test.invalid/v1/ai/video/edit-plan";
const videoTranscriptionUrl = "http://runtime-test.invalid/v1/ai/video/transcribe";

async function startRuntimeWorker() {
  const worker = await unstable_startWorker({
    config: runtimeConfigPath,
    projectRoot: gatewayRoot,
    envFiles: [runtimeEnvPath],
    logLevel: "none",
    dev: { persist: false },
  });
  await worker.ready;
  return worker;
}

async function startRuntimeHarness() {
  const contents = await readFile(runtimeEnvPath, "utf8");
  const secrets = Object.fromEntries(
    contents
      .split(/\r?\n/)
      .filter((line) => line.trim().length > 0)
      .map((line) => {
        const separator = line.indexOf("=");
        return [line.slice(0, separator), line.slice(separator + 1)];
      }),
  );
  const harness = createTestHarness({
    root: gatewayRoot,
    workers: [{ configPath: runtimeConfigPath, secrets }],
  });
  await harness.listen();
  const worker = harness.getWorker();
  return {
    fetch: worker.fetch,
    getEnv: worker.getEnv,
    dispose: () => harness.close(),
  };
}

async function sendText(worker, token, deviceSession) {
  const headers = {
    "Content-Type": "application/json",
    "X-Ovexiq-Beta-Token": token,
  };
  if (deviceSession !== undefined) {
    headers["X-Ovexiq-Device-Session"] = deviceSession;
  }
  return worker.fetch(textUrl, {
    method: "POST",
    headers,
    body: JSON.stringify({ messages: [{ role: "user", content: "runtime quota test" }] }),
  });
}

async function sendImage(worker, token, deviceSession) {
  const headers = {
    "Content-Type": "application/json",
    "X-Ovexiq-Beta-Token": token,
  };
  if (deviceSession !== undefined) {
    headers["X-Ovexiq-Device-Session"] = deviceSession;
  }
  return worker.fetch(imageUrl, {
    method: "POST",
    headers,
    body: JSON.stringify({ prompt: "runtime quota test" }),
  });
}

async function sendVideoEditPlan(worker) {
  return worker.fetch(videoEditPlanUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: "{}",
  });
}

async function sendSpeech(worker, token, deviceSession) {
  const headers = {
    "Content-Type": "application/json",
    "X-Ovexiq-Beta-Token": token,
  };
  if (deviceSession !== undefined) {
    headers["X-Ovexiq-Device-Session"] = deviceSession;
  }
  return worker.fetch(speechUrl, {
    method: "POST",
    headers,
    body: JSON.stringify({ text: "runtime session test" }),
  });
}

async function sendVideoTranscription(worker) {
  const form = new FormData();
  form.set("clipId", "runtime-video-clip");
  form.set(
    "audio",
    new Blob([new Uint8Array([1, 2, 3])], { type: "audio/mp4" }),
    "clip.m4a",
  );
  return worker.fetch(videoTranscriptionUrl, {
    method: "POST",
    body: form,
  });
}

async function activateBetaAccount(worker, activationId) {
  return worker.fetch(activationUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Ovexiq-Beta-Token": "runtime-test-token-one",
    },
    body: JSON.stringify({
      inviteCode: "runtime-test-invite-one",
      activationId,
    }),
  });
}

async function activeSession(worker, activationId, token = "runtime-test-token-one") {
  const response = await worker.fetch(activationUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Ovexiq-Beta-Token": token,
    },
    body: JSON.stringify({
      inviteCode: "runtime-test-invite-one",
      activationId,
    }),
  });
  assert.ok(response.status === 201 || response.status === 200);
  return (await response.json()).deviceSession;
}

async function assertProviderUnavailable(response, code = "provider_unavailable") {
  const body = await response.json();
  assert.equal(response.status, 503);
  assert.equal(body.error.code, code);
}

async function assertQuotaRejected(response) {
  const body = await response.json();
  assert.equal(response.status, 429);
  assert.equal(body.error.code, "beta_limit_reached");
}

test("local Workerd Durable Object enforces the real text and image quota bindings", async (t) => {
  const worker = await startRuntimeWorker();
  t.after(() => worker.dispose());
  const sessionOne = await activeSession(
    worker,
    "runtime-quota-installation-one-abcdefghijklmnop",
  );
  const sessionTwo = await activeSession(
    worker,
    "runtime-quota-installation-two-abcdefghijklmnop",
    "runtime-test-token-two",
  );

  for (let index = 0; index < 20; index += 1) {
    await assertProviderUnavailable(await sendText(worker, "runtime-test-token-one", sessionOne));
  }
  await assertQuotaRejected(await sendText(worker, "runtime-test-token-one", sessionOne));

  for (let index = 0; index < 10; index += 1) {
    await assertProviderUnavailable(await sendText(worker, "runtime-test-token-two", sessionTwo));
  }
  await assertQuotaRejected(await sendText(worker, "runtime-test-token-two", sessionTwo));

  for (let index = 0; index < 2; index += 1) {
    await assertProviderUnavailable(
      await sendImage(worker, "runtime-test-token-one", sessionOne),
      "image_generation_unavailable",
    );
  }
  await assertQuotaRejected(await sendImage(worker, "runtime-test-token-one", sessionOne));

  await assertProviderUnavailable(
    await sendImage(worker, "runtime-test-token-two", sessionTwo),
    "image_generation_unavailable",
  );
  await assertQuotaRejected(await sendImage(worker, "runtime-test-token-two", sessionTwo));
});
test("local Workerd serializes concurrent requests through the real Durable Object", async (t) => {
  const worker = await startRuntimeWorker();
  t.after(() => worker.dispose());
  const session = await activeSession(
    worker,
    "runtime-concurrency-installation-abcdefghijklmnop",
  );

  const responses = await Promise.all(
    Array.from({ length: 25 }, () => sendText(worker, "runtime-test-token-one", session)),
  );
  const statuses = await Promise.all(responses.map((response) => response.status));

  assert.equal(statuses.filter((status) => status === 503).length, 20);
  assert.equal(statuses.filter((status) => status === 429).length, 5);
});

test("local Workerd requires active sessions for every budgeted route", async (t) => {
  const worker = await startRuntimeHarness();
  t.after(() => worker.dispose());
  const activation = await (await activateBetaAccount(
    worker,
    "runtime-session-installation-abcdefghijklmnop",
  )).json();

  const activeResponses = await Promise.all([
    sendText(worker, "runtime-test-token-one", activation.deviceSession),
    sendImage(worker, "runtime-test-token-one", activation.deviceSession),
    sendSpeech(worker, "runtime-test-token-one", activation.deviceSession),
  ]);
  for (const response of activeResponses) {
    assert.equal(response.status, 503);
  }

  const missingResponses = await Promise.all([
    sendText(worker, "runtime-test-token-one"),
    sendImage(worker, "runtime-test-token-one"),
    sendSpeech(worker, "runtime-test-token-one"),
  ]);
  for (const response of missingResponses) {
    const body = await response.json();
    assert.equal(response.status, 401);
    assert.equal(body.error.code, "unauthorized");
  }

  const env = await worker.getEnv();
  const account = env.BETA_ACCOUNTS.getByName(
    "ovexiq-beta-account:runtime-invite-one",
  );
  assert.equal(
    (await account.revokeSession(activation.deviceSession.split(".")[2])).revoked,
    true,
  );
  const revokedResponses = await Promise.all([
    sendText(worker, "runtime-test-token-one", activation.deviceSession),
    sendImage(worker, "runtime-test-token-one", activation.deviceSession),
    sendSpeech(worker, "runtime-test-token-one", activation.deviceSession),
  ]);
  for (const response of revokedResponses) {
    const body = await response.json();
    assert.equal(response.status, 401);
    assert.equal(body.error.code, "unauthorized");
  }
});

test("local Workerd rejects both video routes before any provider work", async (t) => {
  const worker = await startRuntimeWorker();
  t.after(() => worker.dispose());

  const editPlan = await sendVideoEditPlan(worker);
  const transcription = await sendVideoTranscription(worker);

  await assertProviderUnavailable(editPlan, "beta_video_unavailable");
  await assertProviderUnavailable(transcription, "beta_video_unavailable");
});

test("local Workerd creates one invite-bound account and reuses it on activation retry", async (t) => {
  const worker = await startRuntimeWorker();
  t.after(() => worker.dispose());
  const activationId = "runtime-installation-id-abcdefghijklmnopqrstuv";

  const firstResponse = await activateBetaAccount(worker, activationId);
  const first = await firstResponse.json();
  const retryResponse = await activateBetaAccount(worker, activationId);
  const retry = await retryResponse.json();

  assert.equal(firstResponse.status, 201);
  assert.equal(retryResponse.status, 200);
  assert.match(first.accountId, /^acct_[0-9a-f-]{36}$/);
  assert.equal(retry.accountId, first.accountId);
  assert.equal(retry.deviceSession, first.deviceSession);
  assert.equal("recoveryCode" in retry, false);
});

test("local Workerd rejects an activation retry after its installation is revoked", async (t) => {
  const worker = await startRuntimeHarness();
  t.after(() => worker.dispose());
  const activationId = "runtime-installation-id-abcdefghijklmnopqrstuv";

  const activation = await (await activateBetaAccount(worker, activationId)).json();
  const env = await worker.getEnv();
  const account = env.BETA_ACCOUNTS.getByName("ovexiq-beta-account:runtime-invite-one");

  assert.equal(
    (await account.revokeSession(activation.deviceSession.split(".")[2])).revoked,
    true,
  );

  const retryResponse = await activateBetaAccount(worker, activationId);
  const retry = await retryResponse.json();

  assert.equal(retryResponse.status, 403);
  assert.equal(retry.error.code, "installation_revoked");
  assert.equal("deviceSession" in retry, false);
  assert.equal("recoveryCode" in retry, false);
  assert.equal(await account.authenticateSession({
    sessionId: activation.deviceSession.split(".")[2],
    sessionSecret: activation.deviceSession.split(".")[3],
  }), null);
});
