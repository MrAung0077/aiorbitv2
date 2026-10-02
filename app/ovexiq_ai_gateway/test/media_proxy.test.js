import test from 'node:test';
import assert from 'node:assert/strict';
import { proxyMedia } from '../src/media_proxy.js';

const accountId = 'acct_00000000-0000-4000-8000-000000000001';
const env = { OVEXIQ_MEDIA_ENABLED: 'true', OVEXIQ_MEDIA_ALLOWED_ACCOUNTS: JSON.stringify([accountId]),
  OVEXIQ_MEDIA_ORIGIN: 'https://media.example.test', OVEXIQ_MEDIA_SERVICE_KEY: 'synthetic-service-key',
  OVEXIQ_BETA_TOKENS: 'synthetic-test-config', OVEXIQ_MEDIA_WEB_ORIGIN: 'https://app.example.test' };
const request = (extra = {}) => new Request('https://api.example.test/v1/media/projects', {
  headers: { 'x-ovexiq-beta-token': 'synthetic-beta', 'x-ovexiq-device-session': 'synthetic-session', 'x-ovexiq-account': 'spoofed', ...extra },
});
const auth = { findTester: async () => 'tester', authenticate: async () => ({ accountId }) };

test('same contract for Android and web: ownership server-derived, only service credentials forwarded', async () => {
  for (const headers of [{}, { origin: env.OVEXIQ_MEDIA_WEB_ORIGIN }]) {
    const response = await proxyMedia(request(headers), env, { ...auth, fetcher: async (url, init) => {
      assert.equal(url.href, 'https://media.example.test/v1/media/projects');
      assert.equal(init.headers['X-Ovexiq-Account'], accountId);
      assert.equal(init.headers.Authorization, `Bearer ${env.OVEXIQ_MEDIA_SERVICE_KEY}`);
      assert.doesNotMatch(JSON.stringify(init.headers), /synthetic-beta|synthetic-session|spoofed/);
      return Response.json({ projects: [] }, { headers: { 'Set-Cookie': 'never-forward', 'X-Private': 'omit' } });
    } });
    assert.equal(response.status, 200); assert.equal(response.headers.get('set-cookie'), null);
    if (headers.origin) assert.equal(response.headers.get('access-control-allow-origin'), headers.origin);
  }
});

for (const [name, changedEnv, changedAuth, status] of [
  ['disabled', { OVEXIQ_MEDIA_ENABLED: 'false' }, {}, 503],
  ['kill switch', { OVEXIQ_BETA_AI_DISABLED: 'yes' }, {}, 503],
  ['no beta token', {}, { findTester: async () => null }, 401],
  ['revoked session', {}, { authenticate: async () => null }, 401],
  ['not allowlisted', { OVEXIQ_MEDIA_ALLOWED_ACCOUNTS: '[]' }, {}, 403],
  ['unsafe origin', { OVEXIQ_MEDIA_ORIGIN: 'http://media.example.test' }, {}, 503],
]) test(`${name}: fails closed before media/provider work`, async () => {
  const response = await proxyMedia(request(), { ...env, ...changedEnv }, { ...auth, ...changedAuth,
    fetcher: async () => { assert.fail('must not forward'); } });
  assert.equal(response.status, status);
  assert.doesNotMatch(await response.text(), /synthetic-|spoofed|acct_/);
});

test('untrusted web origin rejected; trusted preflight contains no secret', async () => {
  assert.equal((await proxyMedia(request({ origin: 'https://evil.test' }), env, auth)).status, 403);
  const response = await proxyMedia(new Request('https://api.example.test/v1/media/projects', {
    method: 'OPTIONS', headers: { origin: env.OVEXIQ_MEDIA_WEB_ORIGIN },
  }), env, {});
  assert.equal(response.status, 204);
  assert.match(response.headers.get('access-control-allow-headers'), /Device-Session/);
});

test('artifact streaming retains metadata, never redirects client to an external handoff', async () => {
  const response = await proxyMedia(request(), env, { ...auth, fetcher: async () => new Response(new Uint8Array([1, 2, 3]), {
    headers: { 'Content-Type': 'audio/mpeg', 'Content-Length': '3', 'X-Artifact-Sha256': 'safe-hash', Location: 'https://untrusted.test' },
  }) });
  assert.equal(response.headers.get('location'), null); assert.equal(response.headers.get('content-type'), 'audio/mpeg');
  assert.deepEqual([...new Uint8Array(await response.arrayBuffer())], [1, 2, 3]);
});
