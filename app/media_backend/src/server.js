import { createServer } from 'node:http';
import { createHash, randomUUID, timingSafeEqual } from 'node:crypto';
import { createReadStream, writeFileSync, unlinkSync, statSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { MediaFailure, requireValue } from './contracts.js';
import { MediaStore, publicProject } from './store.js';
import { SongSpecProvider, LyriaMusicProvider } from './providers.js';
import { FfmpegRenderer } from './render.js';
import { SongWorkflow } from './workflow.js';

function equalSecret(a, b) {
  const hash = value => createHash('sha256').update(value).digest();
  return timingSafeEqual(hash(a), hash(b));
}
async function jsonBody(request) {
  let length = 0; const chunks = [];
  for await (const chunk of request) {
    length += chunk.length;
    if (length > 12 * 1024 * 1024) throw new MediaFailure('body_too_large', 'validation', 413);
    chunks.push(chunk);
  }
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); }
  catch { throw new MediaFailure('invalid_json', 'validation', 400); }
}
function send(response, status, body) {
  response.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
  response.end(JSON.stringify(body));
}

export function mediaServer({ store, renderer, serviceKey }) {
  if (!serviceKey || serviceKey.length < 32) throw new MediaFailure('service_key_missing', 'configuration');
  return createServer(async (req, res) => {
    try {
      if (!equalSecret(req.headers.authorization ?? '', `Bearer ${serviceKey}`)) return send(res, 401, { error: { code: 'unauthorized' } });
      const owner = req.headers['x-ovexiq-account'];
      requireValue(typeof owner === 'string' && /^acct_[a-f0-9-]{36}$/.test(owner));
      const path = new URL(req.url, 'http://internal').pathname;
      if (path === '/v1/media/artist' && req.method === 'GET') return send(res, 200, store.artist(owner));
      if (path === '/v1/media/artist' && req.method === 'PUT') return send(res, 200, store.saveArtist(owner, await jsonBody(req)));
      if (path === '/v1/media/visuals' && req.method === 'POST') {
        const count = store.db.prepare('SELECT COUNT(*) AS n FROM visuals WHERE owner=?').get(owner).n;
        if (count >= 40) throw new MediaFailure('visual_storage_limit', 'storage', 429);
        const input = await jsonBody(req);
        requireValue(['image/png', 'image/jpeg'].includes(input.mimeType) && typeof input.data === 'string' && /^[A-Za-z0-9+/]+={0,2}$/.test(input.data));
        const bytes = Buffer.from(input.data, 'base64');
        requireValue(bytes.length > 100 && bytes.length <= 8 * 1024 * 1024);
        const png = bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]));
        const jpeg = bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
        requireValue(input.mimeType === 'image/png' ? png : jpeg, 'invalid_visual');
        const id = randomUUID(); const folder = join(store.root, 'visuals'); mkdirSync(folder, { recursive: true, mode: 0o700 });
        const source = join(folder, `${id}.input`); const output = join(folder, `${id}.jpg`);
        writeFileSync(source, bytes, { flag: 'wx', mode: 0o600 });
        try {
          const size = await renderer.normalizeVisual(source, output);
          store.addVisual(owner, id, output, size);
          return send(res, 201, { id, ...size });
        } finally { unlinkSync(source); }
      }
      if (path === '/v1/media/projects' && req.method === 'GET') return send(res, 200, { projects: store.list(owner).map(publicProject) });
      if (path === '/v1/media/projects' && req.method === 'POST') {
        await renderer.preflight(); // Fail before any paid work if rendering unavailable.
        return send(res, 202, publicProject(store.create(owner, await jsonBody(req))));
      }
      const match = path.match(/^\/v1\/media\/projects\/([a-f0-9-]{36})(?:\/artifacts\/([a-f0-9-]{36}))?$/);
      if (match && req.method === 'GET') {
        const project = store.get(owner, match[1]);
        if (!project) throw new MediaFailure('not_found', 'lookup', 404);
        if (!match[2]) return send(res, 200, publicProject(project));
        const artifact = project.artifacts.find(item => item.id === match[2]);
        if (!artifact) throw new MediaFailure('not_found', 'lookup', 404);
        const file = join(store.directory(project), artifact.fileName);
        const size = statSync(file).size;
        res.writeHead(200, { 'Content-Type': artifact.mimeType, 'Content-Length': size, 'Cache-Control': 'private, no-store',
          'X-Content-Type-Options': 'nosniff', 'Content-Disposition': `attachment; filename="${artifact.fileName}"`, 'X-Artifact-Sha256': artifact.sha256 });
        const stream = createReadStream(file); stream.on('error', () => res.destroy()); res.on('close', () => stream.destroy()); stream.pipe(res); return;
      }
      throw new MediaFailure('not_found', 'routing', 404);
    } catch (error) {
      if (res.headersSent) { res.destroy(); return; }
      const failure = error instanceof MediaFailure ? error : new MediaFailure('media_service_unavailable', 'service');
      send(res, failure.status, { error: failure.toJSON() });
    }
  });
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const env = process.env;
  // Each provider adapter checks its key only when its paid stage is invoked.
  // Boot, artifact reads and synthetic rendering require no paid-provider keys.
  if (!env.MEDIA_DATA_DIR) throw new Error('Media server configuration incomplete');
  const store = new MediaStore(env.MEDIA_DATA_DIR);
  const renderer = new FfmpegRenderer();
  await renderer.preflight();
  const server = mediaServer({ store, renderer, serviceKey: env.OVEXIQ_MEDIA_SERVICE_KEY });
  // One service replica with an exclusive persistent volume. Crashes leave a
  // reviewable terminal state; no automatic replay of paid requests.
  store.interruptUncertain();
  const workflow = new SongWorkflow({ store, renderer,
    textProvider: new SongSpecProvider({ apiKey: env.OPENROUTER_API_KEY }),
    musicProvider: new LyriaMusicProvider({ apiKey: env.GEMINI_API_KEY }) });
  let busy = false;
  setInterval(async () => {
    if (busy) return;
    const job = store.next(); if (!job) return;
    busy = true;
    try { await workflow.run(job); }
    catch { /* Do not print private content/errors; recovery marks uncertain jobs. */ }
    finally { busy = false; }
  }, 1000);
  server.listen(Number(env.PORT ?? 8080), '0.0.0.0');
}
