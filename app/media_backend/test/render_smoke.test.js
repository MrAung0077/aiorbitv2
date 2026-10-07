import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, statSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { createHash, randomUUID } from 'node:crypto';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { request } from 'node:http';
import { fileURLToPath } from 'node:url';
import { FfmpegRenderer, runProcess } from '../src/render.js';
import { MediaStore, publicProject } from '../src/store.js';
import { SongWorkflow } from '../src/workflow.js';
import { SyntheticMediaProvider, simulatedCrash } from './fixtures/synthetic_media_provider.js';

function getLocal(port, path, headers) {
  return new Promise((resolve, reject) => {
    const req = request({ host: '127.0.0.1', port, path, headers }, res => {
      const chunks = [];
      res.on('data', chunk => chunks.push(chunk));
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, bytes: Buffer.concat(chunks) }));
    });
    req.on('error', reject); req.setTimeout(3000, () => req.destroy(new Error('local_probe_timeout'))); req.end();
  });
}

// Synthetic-only; run inside the server image with --network none and no keys.
test('real render, durable artifacts and keyless service boot', { skip: process.env.MEDIA_RENDER_SMOKE !== '1', timeout: 900000 }, async t => {
  const renderer = new FfmpegRenderer(); await renderer.preflight();
  const parent = process.env.MEDIA_SMOKE_OUTPUT_DIR ?? tmpdir();
  mkdirSync(parent, { recursive: true });
  const root = mkdtempSync(join(parent, 'ovexiq-render-smoke-'));
  let openStore, child, provider;
  t.after(async () => {
    if (child?.pid && child.exitCode === null && child.signalCode === null) {
      const stopped = once(child, 'exit'); child.kill(); await stopped;
    }
    openStore?.close();
    provider?.close();
    if (!process.env.MEDIA_SMOKE_OUTPUT_DIR) rmSync(root, { recursive: true, force: true });
  });
  const originalFetch = globalThis.fetch;
  let providerCalls = 0;
  globalThis.fetch = async () => { providerCalls++; throw new Error('external_fetch_forbidden'); };
  t.after(() => { globalThis.fetch = originalFetch; });
  let now = Date.now();
  let store = new MediaStore(root, { clock: () => now }); openStore = store;
  const owner = `acct_${randomUUID()}`, ids = [];
  for (const [index, color] of ['red', 'green', 'blue', 'gray'].entries()) {
    const file = join(root, `${index}.jpg`), id = randomUUID(); ids.push(id);
    await runProcess('ffmpeg', ['-nostdin', '-v', 'error', '-f', 'lavfi', '-i', `color=c=${color}:s=1280x720`, '-frames:v', '1', '-threads', '1', file]);
    store.addVisual(owner, id, file, { width: 1280, height: 720 });
  }
  store.saveArtist(owner, { artistName: 'Synthetic Test', visualReferenceIds: ids });
  const source = join(root, 'synthetic.mp3');
  await runProcess('ffmpeg', ['-nostdin', '-v', 'error', '-f', 'lavfi', '-i', 'sine=frequency=220:sample_rate=44100', '-t', '48', '-c:a', 'libmp3lame', source]);
  const productionSource = join(root, 'synthetic.flac');
  await runProcess('ffmpeg', ['-nostdin', '-v', 'error', '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=48000', '-t', '48', '-c:a', 'flac', productionSource]);
  let textCalls = 0;
  const project = store.create(owner, { requestId: randomUUID(), goal: 'Synthetic render validation only', language: 'en' });
  const providerPath = join(root, 'synthetic-provider.sqlite');
  provider = new SyntheticMediaProvider(providerPath, { clock: () => now, delayMs: 0, primaryArtifactKey: 'preview', artifacts: [
    { key: 'preview', role: 'combined_mix', mimeType: 'audio/mpeg', extension: 'mp3', format: 'mp3', codec: 'mp3', bytes: readFileSync(source) },
    { key: 'production', role: 'stem', mimeType: 'audio/flac', extension: 'flac', format: 'flac', codec: 'flac',
      technicalMetadata: { sampleRate: 48000, lossless: true }, bytes: readFileSync(productionSource) },
  ] });
  const renderCounts = { landscape: 0, portrait: 0 };
  const realExport = renderer.export.bind(renderer);
  let interruptRender = true, interruptedFile;
  renderer.export = async args => {
    const selected = store.get(owner, project.projectId).audioArtifact;
    assert.equal(selected.providerArtifactKey, 'preview');
    assert.equal(args.audio, join(root, project.projectId, selected.fileName));
    renderCounts[args.width > args.height ? 'landscape' : 'portrait']++;
    const result = await realExport(args);
    // Deterministic worker interruption after real encode/probe/full decode, before publication.
    // No live FFmpeg child is killed and no production renderer behavior is changed.
    if (interruptRender) { interruptRender = false; interruptedFile = args.output; throw simulatedCrash(); }
    return result;
  };
  const makeWorkflow = hook => new SongWorkflow({ store, renderer, hook,
    textProvider: { async create() { textCalls++; return { title: 'Synthetic test', language: 'en', theme: 'test', genre: 'test',
      mood: 'test', tempoDirection: 'test', instrumentation: 'sine', vocalCharacteristics: 'none', structure: 'test',
      lyrics: '[Verse 1]\nSynthetic fixture\n[Chorus]\nNo singing or provider call', chorusStartSeconds: 12 }; } },
    musicProvider: provider,
  });
  const restart = () => {
    store.close(); provider.close(); now += 60000;
    store = new MediaStore(root, { clock: () => now }); openStore = store;
    provider = new SyntheticMediaProvider(providerPath, { clock: () => now, delayMs: 0, bytes: readFileSync(source) });
    store.interruptUncertain();
  };
  const started = Date.now();
  await assert.rejects(makeWorkflow(async (point, { stage }) => {
    if (point === 'provider_accepted' && stage.kind === 'music') throw simulatedCrash();
  }).run(project), error => error.simulatedCrash);
  restart();
  await assert.rejects(makeWorkflow().run(project), error => error.simulatedCrash);
  assert.ok(statSync(interruptedFile).size > 0);
  const durableAudio = store.get(owner, project.projectId).artifacts.filter(a => a.mediaType === 'audio');
  assert.equal(durableAudio.length, 2);
  assert.equal(store.db.prepare('SELECT COUNT(*) AS n FROM media_artifacts WHERE json_extract(payload, \'$.mimeType\')=\'video/mp4\'').get().n, 0);
  assert.equal(provider.count(), 1); assert.equal(textCalls, 1);
  // Expire upstream locators: recovery must use Ovexiq-owned bytes for both audio outputs.
  provider.db.exec('DELETE FROM outputs');
  restart();
  let rendered;
  await assert.rejects(makeWorkflow(async (point, { stage, artifact }) => {
    if (point === 'artifact_published' && stage.kind === 'render_full') { rendered = artifact; throw simulatedCrash(); }
  }).run(project), error => error.simulatedCrash);
  restart(); await makeWorkflow().run(project);
  assert.equal(project.status, 'completed', JSON.stringify(project.failure));
  assert.deepEqual(project.artifacts.find(a => a.fileName === 'youtube.mp4'), rendered);
  assert.equal(provider.count(), 1); assert.equal(store.jobs.events().length, 1);
  assert.equal(project.artifacts.length, 5);
  assert.equal(new Set(project.artifacts.map(a => a.id)).size, 5);
  assert.equal(store.db.prepare('SELECT COUNT(*) AS n FROM media_artifacts').get().n, 5);
  assert.deepEqual(project.artifacts.filter(a => a.mediaType === 'audio'), durableAudio);
  assert.equal(project.primaryArtifactId, project.audioArtifact.id);
  assert.equal(project.audioArtifact.providerArtifactKey, 'preview');
  assert.deepEqual(renderCounts, { landscape: 2, portrait: 1 });
  const stableArtifacts = structuredClone(project.artifacts);
  restart(); await makeWorkflow().tick();
  assert.deepEqual(store.get(owner, project.projectId).artifacts, stableArtifacts);
  assert.deepEqual(renderCounts, { landscape: 2, portrait: 1 });
  const checks = [];
  for (const artifact of project.artifacts) {
    const file = join(root, project.projectId, artifact.fileName);
    assert.ok(statSync(file).size > 0); assert.equal(statSync(file).size, artifact.byteSize);
    assert.equal(createHash('sha256').update(readFileSync(file)).digest('hex'), artifact.sha256);
    if (artifact.mimeType === 'video/mp4') {
      const info = await renderer.probe(file);
      assert.ok(info.format.format_name.split(',').includes('mp4'));
      const video = info.streams.find(s => s.codec_type === 'video'), audio = info.streams.find(s => s.codec_type === 'audio');
      assert.equal(video.codec_name, 'h264'); assert.equal(audio.codec_name, 'aac');
      const full = artifact.fileName === 'youtube.mp4';
      assert.equal(video.width, full ? 1280 : 720); assert.equal(video.height, full ? 720 : 1280);
      assert.ok(Math.abs(Number(info.format.duration) - (full ? project.audioArtifact.durationSeconds : 30)) < 0.5);
      await runProcess('ffmpeg', ['-nostdin', '-v', 'error', '-xerror', '-i', file, '-f', 'null', '-']);
      checks.push({ ...artifact, container: info.format.format_name, decode: 'PASS' });
    } else if (artifact.mediaType === 'audio') {
      const info = await renderer.probe(file);
      assert.equal(info.streams.find(s => s.codec_type === 'audio').codec_name, artifact.codec);
      assert.ok(Math.abs(Number(info.format.duration) - 48) < 0.5);
      await runProcess('ffmpeg', ['-nostdin', '-v', 'error', '-xerror', '-i', file, '-f', 'null', '-']);
      checks.push({ ...artifact, decode: 'PASS' });
    }
  }
  const portable = JSON.stringify(publicProject(project));
  assert.ok(!portable.includes(root)); assert.doesNotMatch(portable, /[A-Z]:\\|file:\/\//);
  store.close(); openStore = null;
  const reopened = new MediaStore(root); openStore = reopened;
  assert.deepEqual(reopened.get(owner, project.projectId), project);
  assert.equal(reopened.next(), undefined); reopened.close(); openStore = null;

  // Boot the real entry point with both provider keys absent. An IPC-only test
  // preload discovers its ephemeral listening port without production changes.
  const serviceKey = randomUUID() + randomUUID();
  const childEnv = { ...process.env, MEDIA_DATA_DIR: root, OVEXIQ_MEDIA_SERVICE_KEY: serviceKey, PORT: '0' };
  delete childEnv.GEMINI_API_KEY; delete childEnv.OPENROUTER_API_KEY;
  const preload = join(root, 'listen-probe.cjs');
  writeFileSync(preload, "const http=require('node:http');const listen=http.Server.prototype.listen;http.Server.prototype.listen=function(...a){this.once('listening',()=>process.send({port:this.address().port}));return listen.apply(this,a)};", { mode: 0o600 });
  child = spawn(process.execPath, ['--require', preload, fileURLToPath(new URL('../src/server.js', import.meta.url))], {
    env: childEnv, windowsHide: true, stdio: ['ignore', 'ignore', 'ignore', 'ipc'],
  });
  const [{ port }] = await once(child, 'message', { signal: AbortSignal.timeout(15000) });
  assert.ok(port > 0);
  assert.equal((await getLocal(port, '/v1/media/projects', {})).status, 401);
  const headers = { Authorization: `Bearer ${serviceKey}`, 'X-Ovexiq-Account': owner };
  const history = await getLocal(port, '/v1/media/projects', headers);
  assert.equal(history.status, 200); assert.equal(JSON.parse(history.bytes).projects[0].status, 'completed');
  const canonical = await getLocal(port, `/v1/media/projects/${project.projectId}`, headers);
  assert.equal(canonical.status, 200);
  assert.deepEqual(JSON.parse(canonical.bytes).artifacts, stableArtifacts);
  assert.equal(JSON.parse(canonical.bytes).primaryArtifactId, project.primaryArtifactId);
  for (const artifact of project.artifacts) {
    const download = await getLocal(port, `/v1/media/projects/${project.projectId}/artifacts/${artifact.id}`, headers);
    assert.equal(download.status, 200);
    assert.equal(download.bytes.length, artifact.byteSize);
    assert.equal(download.headers['content-type'], artifact.mimeType);
    assert.equal(createHash('sha256').update(download.bytes).digest('hex'), artifact.sha256);
    assert.equal(download.headers['x-artifact-sha256'], artifact.sha256);
  }
  assert.equal(providerCalls, 0); assert.equal(textCalls, 1); assert.equal(provider.count(), 1);
  const report = { platform: process.platform, node: process.version,
    ffmpeg: (await runProcess('ffmpeg', ['-version'])).split('\n')[0], elapsedMs: Date.now() - started,
    keylessBoot: 'PASS', persistenceReopen: 'PASS', authenticatedDownload: 'PASS', providerCalls,
    syntheticExecutionCount: provider.count(), providerAcceptanceRecovery: 'PASS', renderPublicationRecovery: 'PASS', completionEventCount: 1,
    temporaryRenderRecovery: 'PASS', renderCounts, multiArtifactRetention: 'PASS', primarySourceSelection: 'PASS', registeredArtifactCount: project.artifacts.length,
    recoveryBoundary: 'Injected worker interruption after real temporary encode/probe/full decode, before publication; SQLite/provider reopened and lease expired. Local landscape render repeats once.',
    projectId: project.projectId, artifacts: checks };
  writeFileSync(join(root, 'smoke-report.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify({ smokeOutputDirectory: root, ...report }));
});
