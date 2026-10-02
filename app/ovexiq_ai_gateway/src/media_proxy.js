// Only allow explicitly provisioned personal-media accounts. The beta token
// alone is never spend authority. Existing text/image/speech quotas are separate.
export async function proxyMedia(request, env, { authenticate, findTester, fetcher = fetch }) {
  const origin = request.headers.get('origin');
  const allowedOrigin = env.OVEXIQ_MEDIA_WEB_ORIGIN;
  const cors = origin && origin === allowedOrigin ? { 'Access-Control-Allow-Origin': origin, Vary: 'Origin',
    'Access-Control-Allow-Headers': 'Content-Type, X-Ovexiq-Beta-Token, X-Ovexiq-Device-Session',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, OPTIONS', 'Access-Control-Expose-Headers': 'Content-Length, X-Artifact-Sha256, Content-Disposition' } : {};
  const error = (status, code) => Response.json({ error: { code } }, { status, headers: { ...cors, 'Cache-Control': 'no-store' } });
  if (origin && origin !== allowedOrigin) return error(403, 'origin_not_allowed');
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (env.OVEXIQ_MEDIA_ENABLED !== 'true') return error(503, 'media_not_configured');
  if (['1', 'true', 'yes', 'on'].includes(String(env.OVEXIQ_BETA_AI_DISABLED).trim().toLowerCase())) return error(503, 'media_unavailable');
  try {
    if (await findTester(env.OVEXIQ_BETA_TOKENS, request.headers.get('x-ovexiq-beta-token') ?? '') === null) return error(401, 'unauthorized');
    const account = await authenticate(env, request.headers.get('x-ovexiq-device-session') ?? '');
    if (!account) return error(401, 'unauthorized');
    const allowed = JSON.parse(env.OVEXIQ_MEDIA_ALLOWED_ACCOUNTS ?? '[]');
    if (!Array.isArray(allowed) || !allowed.includes(account.accountId)) return error(403, 'media_access_not_enabled');
    const base = new URL(env.OVEXIQ_MEDIA_ORIGIN);
    if (base.protocol !== 'https:' || base.username || base.password || base.pathname !== '/' || base.search || !env.OVEXIQ_MEDIA_SERVICE_KEY) return error(503, 'media_not_configured');
    const path = new URL(request.url).pathname;
    if (!/^\/v1\/media\/(?:artist|visuals|projects(?:\/[a-f0-9-]{36}(?:\/artifacts\/[a-f0-9-]{36})?)?)$/.test(path)) return error(404, 'not_found');
    if (!['GET', 'POST', 'PUT'].includes(request.method)) return error(405, 'method_not_allowed');
    if (request.method !== 'GET' && (!request.headers.get('content-type')?.startsWith('application/json') || Number(request.headers.get('content-length') ?? 0) > 12 * 1024 * 1024)) return error(413, 'invalid_body');
    const upstream = await fetcher(new URL(path, base), {
      method: request.method, body: request.body, redirect: 'error',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${env.OVEXIQ_MEDIA_SERVICE_KEY}`, 'X-Ovexiq-Account': account.accountId },
    });
    const headers = new Headers(cors);
    for (const name of ['content-type', 'content-length', 'content-disposition', 'x-artifact-sha256']) {
      const value = upstream.headers.get(name); if (value) headers.set(name, value);
    }
    headers.set('Cache-Control', 'private, no-store'); headers.set('X-Content-Type-Options', 'nosniff');
    return new Response(upstream.body, { status: upstream.status, headers });
  } catch { return error(503, 'media_service_unavailable'); }
}
