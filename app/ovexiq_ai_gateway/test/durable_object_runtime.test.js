import assert from "node:assert/strict";
import test from "node:test";
import { fileURLToPath } from "node:url";
import path from "node:path";

import { unstable_startWorker } from "wrangler";

const gatewayRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const runtimeConfigPath = path.join(gatewayRoot, "wrangler.runtime-test.jsonc");
const runtimeEnvPath = path.join(gatewayRoot, "test", "runtime.test.env");
const textUrl = "http://runtime-test.invalid/v1/ai/complete";
const imageUrl = "http://runtime-test.invalid/v1/ai/image";

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

async function sendText(worker, token) {
  return worker.fetch(textUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Ovexiq-Beta-Token": token,
    },
    body: JSON.stringify({ messages: [{ role: "user", content: "runtime quota test" }] }),
  });
}

async function sendImage(worker, token) {
  return worker.fetch(imageUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Ovexiq-Beta-Token": token,
    },
    body: JSON.stringify({ prompt: "runtime quota test" }),
  });
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

  for (let index = 0; index < 20; index += 1) {
    await assertProviderUnavailable(await sendText(worker, "runtime-test-token-one"));
  }
  await assertQuotaRejected(await sendText(worker, "runtime-test-token-one"));

  for (let index = 0; index < 10; index += 1) {
    await assertProviderUnavailable(await sendText(worker, "runtime-test-token-two"));
  }
  await assertQuotaRejected(await sendText(worker, "runtime-test-token-two"));

  for (let index = 0; index < 2; index += 1) {
    await assertProviderUnavailable(
      await sendImage(worker, "runtime-test-token-one"),
      "image_generation_unavailable",
    );
  }
  await assertQuotaRejected(await sendImage(worker, "runtime-test-token-one"));

  await assertProviderUnavailable(
    await sendImage(worker, "runtime-test-token-two"),
    "image_generation_unavailable",
  );
  await assertQuotaRejected(await sendImage(worker, "runtime-test-token-two"));
});

test("local Workerd serializes concurrent requests through the real Durable Object", async (t) => {
  const worker = await startRuntimeWorker();
  t.after(() => worker.dispose());

  const responses = await Promise.all(
    Array.from({ length: 25 }, () => sendText(worker, "runtime-test-token-one")),
  );
  const statuses = await Promise.all(responses.map((response) => response.status));

  assert.equal(statuses.filter((status) => status === 503).length, 20);
  assert.equal(statuses.filter((status) => status === 429).length, 5);
});
