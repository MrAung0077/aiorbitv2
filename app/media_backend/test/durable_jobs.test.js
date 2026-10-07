import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { randomUUID, createHash } from 'node:crypto';
import { request } from 'node:http';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { MediaStore } from '../src/store.js';
import { SongWorkflow } from '../src/workflow.js';
import { SongExecution, LeaseLost } from '../src/media_jobs.js';
import { MediaFailure } from '../src/contracts.js';
import { mediaServer } from '../src/server.js';
import { SyntheticMediaProvider, simulatedCrash } from './fixtures/synthetic_media_provider.js';

const spec = { title: 'Fixture', language: 'en', theme: 'test', genre: 'test', mood: 'test', tempoDirection: 'test',
  instrumentation: 'sine', vocalCharacteristics: 'fixture', structure: 'verse chorus', lyrics: '[Verse 1]\nTest\n[Chorus]\nTest', chorusStartSeconds: 12 };
function fixture(t, { create = true } = {}) {
  const root = mkdtempSync(join(tmpdir(), 'ovexiq-durable-'));
  const f = { root, now: 100000, owner: `acct_${randomUUID()}`, textCalls: 0, renders: [] };
  f.open = () => {
    f.store = new MediaStore(root, { clock: () => f.now });
    f.provider = new SyntheticMediaProvider(join(root, 'synthetic.sqlite'), { clock: () => f.now });
  };
  f.open();
  f.reopen = () => { f.store.close(); f.provider.close(); f.now += 60000; f.open(); f.store.interruptUncertain(); };
  t.after(() => { f.store.close(); f.provider.close(); rmSync(root, { recursive: true, force: true }); });
  const ids = Array.from({ length: 4 }, () => randomUUID());
  ids.forEach(id => f.store.addVisual(f.owner, id, join(root, `${id}.jpg`), { width: 1280, height: 720 }));
  f.store.saveArtist(f.owner, { artistName: 'Fixture', visualReferenceIds: ids });
  f.input = { requestId: randomUUID(), goal: 'Create a synthetic original song', language: 'en' };
  f.project = create ? f.store.create(f.owner, f.input) : null;
  f.renderer = { async preflight() {}, async validateAudio() { return 48; }, async export(args) {
    f.renders.push(args.width); writeFileSync(args.output, Buffer.alloc(256, args.width === 1280 ? 2 : 3));
    return { width: args.width, height: args.height, durationSeconds: args.duration, videoCodec: 'h264', audioCodec: 'aac' };
  } };
  f.workflow = (overrides = {}) => new SongWorkflow({ store: f.store, renderer: f.renderer, musicProvider: f.provider,
    textProvider: { async create() { f.textCalls++; return structuredClone(spec); } }, ...overrides });
  f.finish = async () => { for (let i = 0; i < 6; i++) { f.now += 60000; await f.workflow().tick(); } return f.store.get(f.owner, f.project.projectId); };
  return f;
}

function call(server, method, path, body, headers) {
  return new Promise((resolve, reject) => {
    const req = request({ host: '127.0.0.1', port: server.address().port, method, path,
      headers: { ...headers, 'content-type': 'application/json' } }, res => {
      const chunks = []; res.on('data', chunk => chunks.push(chunk));
      res.on('end', () => resolve({ status: res.statusCode, bytes: Buffer.concat(chunks), headers: res.headers }));
    });
    req.on('error', reject); req.end(body && JSON.stringify(body));
  });
}

test('A B C N R: acknowledgement, lost client, same-key recovery, passive history and download', async t => {
  const f = fixture(t, { create: false }), serviceKey = 'synthetic-local-service-key-with-no-real-access';
  const server = mediaServer({ store: f.store, renderer: f.renderer, serviceKey });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  t.after(() => new Promise(resolve => server.close(resolve)));
  const headers = { authorization: `Bearer ${serviceKey}`, 'x-ovexiq-account': f.owner };
  const post = () => call(server, 'POST', '/v1/media/projects', f.input, headers);
  const ack = await post(); assert.equal(ack.status, 202);
  const id = JSON.parse(ack.bytes).projectId;
  f.project = f.store.get(f.owner, id);
  assert.ok(f.store.jobs.forProject(id));
  // Simulate an unobserved acknowledgement. Recovery must not need healthy rendering.
  f.renderer.preflight = async () => { throw new Error('renderer unavailable'); };
  assert.equal(JSON.parse((await post()).bytes).projectId, id);
  f.renderer.preflight = async () => {};
  for (let i = 0; i < 3; i++) await call(server, 'GET', `/v1/media/projects/${id}`, null, headers);
  assert.equal(f.provider.count(), 0);
  const completed = await f.finish(); assert.equal(completed.status, 'completed');
  assert.equal(f.provider.count(), 1); assert.equal(f.textCalls, 1);
  const history = await call(server, 'GET', `/v1/media/projects/${id}`, null, headers);
  const publicValue = JSON.parse(history.bytes);
  assert.equal(publicValue.status, 'completed'); assert.equal(publicValue.submissionSnapshot, undefined);
  for (const artifact of completed.artifacts) {
    const downloaded = await call(server, 'GET', `/v1/media/projects/${id}/artifacts/${artifact.id}`, null, headers);
    assert.equal(downloaded.status, 200);
    assert.equal(createHash('sha256').update(downloaded.bytes).digest('hex'), artifact.sha256);
    assert.equal(downloaded.headers['content-type'], artifact.mimeType);
    assert.notEqual(artifact.id, artifact.versionId);
  }
  assert.equal(f.provider.count(), 1);
});

for (const [label, point, kind] of [
  ['E before provider dispatch', 'before_dispatch', 'music'],
  ['F acceptance before local identity commit', 'provider_accepted', 'music'],
  ['G after external identity commit', 'execution_persisted', 'music'],
  ['H durable provider result before registration', 'result_persisted', 'music'],
  ['P audio publication before registration', 'artifact_published', 'audio_publication'],
  ['I rendered file before registration', 'artifact_published', 'render_full'],
]) test(`${label}: restart reconciles one generation`, async t => {
  const f = fixture(t);
  f.provider.delayMs = 0;
  let stopped = false, published;
  const workflow = f.workflow({ hook: async (event, details) => {
    if (!stopped && event === point && details.stage.kind === kind) {
      stopped = true; published = details.artifact; throw simulatedCrash();
    }
  } });
  await assert.rejects(workflow.run(f.project), e => e.simulatedCrash);
  const before = f.store.db.prepare('SELECT payload FROM media_attempts').all().map(r => JSON.parse(r.payload));
  const attempt = before.find(a => a.stageType === 'music');
  assert.notEqual(attempt.id, attempt.stageId); assert.notEqual(attempt.stageId, f.project.projectId);
  assert.notEqual(attempt.id, f.input.requestId);
  if (point === 'execution_persisted') assert.ok(attempt.externalExecutionId);
  f.reopen();
  const saved = await f.finish();
  assert.equal(saved.status, 'completed', JSON.stringify(saved.failure));
  assert.equal(f.provider.count(), 1); assert.equal(f.textCalls, 1);
  assert.equal(new Set(saved.artifacts.map(a => a.id)).size, 4);
  if (published) assert.deepEqual(saved.artifacts.find(a => a.fileName === published.fileName), published);
  const stable = saved.artifacts;
  f.reopen(); assert.deepEqual((await f.finish()).artifacts, stable);
  assert.equal(f.store.jobs.events().length, 1);
});

test('I J: restart during rendering and local failure reuse upstream audio', async t => {
  const f = fixture(t); f.provider.delayMs = 0;
  const render = f.renderer.export; let crash = true;
  f.renderer.export = async args => { if (crash) { writeFileSync(args.output, 'partial'); throw simulatedCrash(); } return render(args); };
  await assert.rejects(f.workflow().run(f.project), e => e.simulatedCrash);
  const audio = f.store.get(f.owner, f.project.projectId).audioArtifact;
  f.reopen(); crash = false;
  let failures = 1;
  f.renderer.export = async args => { if (failures-- > 0) throw new Error('temporary local failure'); return render(args); };
  const completed = await f.finish();
  assert.equal(completed.status, 'completed'); assert.deepEqual(completed.audioArtifact, audio);
  assert.equal(f.provider.count(), 1); assert.equal(f.textCalls, 1);
});

test('K L M: exclusive claim, stale takeover, fenced DB and filesystem publication', async t => {
  const f = fixture(t), second = new MediaStore(f.root, { clock: () => f.now });
  const first = f.store.jobs.claim('first', { leaseMs: 100 });
  assert.equal(second.jobs.claim('second'), null);
  const execution = new SongExecution(f.store, first);
  let complete; const produced = new Promise(resolve => { complete = resolve; });
  const publication = execution.artifact('render_full', 'youtube.mp4', 'video/mp4', {}, async path => {
    writeFileSync(path, 'old worker output'); await produced; return {};
  });
  f.now += 101;
  const recovered = second.jobs.claim('second'); assert.ok(recovered);
  assert.notEqual(first.token, recovered.token);
  assert.throws(() => f.store.jobs.checkpoint(first, f.project, 'stale'), LeaseLost);
  assert.throws(() => f.store.jobs.renew(first), LeaseLost);
  assert.throws(() => f.store.jobs.terminal(first, f.project, 'failed'), LeaseLost);
  complete(); await assert.rejects(publication, LeaseLost);
  assert.equal(second.db.prepare('SELECT COUNT(*) AS n FROM media_artifacts').get().n, 0);
  assert.throws(() => readFileSync(join(f.root, f.project.projectId, 'youtube.mp4')));
  second.close();
});

test('O: unknown live-style outcome never resubmits; failure event survives restart', async t => {
  const f = fixture(t); let calls = 0;
  const unsupported = { supportsLanguage: () => true, async generateSong() { calls++; throw new MediaFailure('provider_timeout_unknown', 'music'); } };
  await f.workflow({ musicProvider: unsupported }).run(f.project);
  assert.equal(f.project.status, 'failed'); assert.equal(f.project.reviewRequired, true);
  f.reopen(); await f.workflow({ musicProvider: unsupported }).tick();
  assert.equal(calls, 1); assert.equal(f.store.jobs.events()[0].status, 'uncertain');
});

test('O: synchronous provider accepted then process lost cannot be blindly replayed', async t => {
  const f = fixture(t); let calls = 0;
  const unsupported = { supportsLanguage: () => true, async generateSong() { calls++; throw simulatedCrash(); } };
  await assert.rejects(f.workflow({ musicProvider: unsupported }).run(f.project), e => e.simulatedCrash);
  f.reopen(); await f.workflow({ musicProvider: unsupported }).tick();
  assert.equal(calls, 1); assert.equal(f.store.jobs.forProject(f.project.projectId).status, 'uncertain');
});

test('Q: unique terminal outbox, restart survival and idempotent fake consumer', async t => {
  const f = fixture(t); await f.finish();
  const event = f.store.jobs.events()[0]; assert.equal(event.artifactReady, true); assert.equal(event.artifactIds.length, 4);
  f.reopen(); assert.deepEqual(f.store.jobs.events(), [event]);
  const received = new Set(); let crash = true;
  const consumer = async value => { received.add(value.id); if (crash) throw simulatedCrash(); };
  await assert.rejects(f.store.jobs.deliver(consumer));
  f.reopen(); crash = false; await f.store.jobs.deliver(consumer); await f.store.jobs.deliver(consumer);
  assert.equal(received.size, 1); assert.equal(f.store.jobs.events().length, 0);
  assert.equal(f.store.db.prepare('SELECT COUNT(*) AS n FROM media_outbox').get().n, 1);
});

test('snapshot persists before dispatch and is reused unchanged after restart', async t => {
  const f = fixture(t); let original;
  await assert.rejects(f.workflow({ hook: async (point, { stage, attempt }) => {
    if (point === 'before_dispatch' && stage.kind === 'music') { original = attempt; throw simulatedCrash(); }
  } }).run(f.project));
  assert.equal(original.status, 'prepared'); assert.ok(original.inputSnapshot.prompt);
  assert.ok(original.inputSnapshot.rights); assert.equal(original.workflowVersion, 'song-durable-v1');
  f.reopen(); await f.finish();
  const recovered = JSON.parse(f.store.db.prepare('SELECT payload FROM media_attempts WHERE id=?').get(original.id).payload);
  assert.deepEqual(recovered.inputSnapshot, original.inputSnapshot); assert.deepEqual(recovered.routeSnapshot, original.routeSnapshot);
  assert.ok(recovered.externalExecutionId); assert.notEqual(recovered.externalExecutionId, recovered.id);
  assert.deepEqual(recovered.artifactIds, [f.store.get(f.owner, f.project.projectId).audioArtifact.id]);
});

test('K: two actual processes racing for one queued job produce one claim', async t => {
  const f = fixture(t);
  const code = `import {MediaStore} from ${JSON.stringify(new URL('../src/store.js', import.meta.url).href)};
    const store = new MediaStore(process.argv[1], {clock:()=>100000});
    const lease = store.jobs.claim(process.argv[2]);
    process.stdout.write(JSON.stringify(lease)); store.close();`;
  const claim = owner => new Promise((resolve, reject) => {
    const child = spawn(process.execPath, ['--input-type=module', '-e', code, f.root, owner], { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
    let output = ''; child.stdout.on('data', chunk => { output += chunk; });
    child.on('error', reject); child.on('exit', code => code === 0 ? resolve(JSON.parse(output)) : reject(new Error('claim_process_failed')));
  });
  const claims = await Promise.all([claim('process-one'), claim('process-two')]);
  assert.equal(claims.filter(Boolean).length, 1);
});

test('F: actual child-process exit after provider acceptance recovers external execution once', async t => {
  const f = fixture(t);
  const storeUrl = new URL('../src/store.js', import.meta.url).href;
  const workflowUrl = new URL('../src/workflow.js', import.meta.url).href;
  const providerUrl = new URL('./fixtures/synthetic_media_provider.js', import.meta.url).href;
  const code = `import {MediaStore} from ${JSON.stringify(storeUrl)};
    import {SongWorkflow} from ${JSON.stringify(workflowUrl)};
    import {SyntheticMediaProvider} from ${JSON.stringify(providerUrl)};
    const store = new MediaStore(process.argv[1], {clock:()=>100000});
    const provider = new SyntheticMediaProvider(process.argv[2], {clock:()=>100000});
    const workflow = new SongWorkflow({store,musicProvider:provider,
      textProvider:{async create(){return ${JSON.stringify(spec)}}},
      renderer:{async preflight(){},async validateAudio(){return 48}},
      hook:async(point,{stage})=>{if(point==='provider_accepted' && stage.kind==='music') process.exit(91)}});
    await workflow.tick(); process.exit(92);`;
  const child = spawn(process.execPath, ['--input-type=module', '-e', code, f.root, join(f.root, 'synthetic.sqlite')],
    { windowsHide: true, stdio: ['ignore', 'ignore', 'pipe'] });
  const [exit] = await once(child, 'exit'); assert.equal(exit, 91);
  assert.equal(f.provider.count(), 1);
  f.reopen(); const completed = await f.finish();
  assert.equal(completed.status, 'completed'); assert.equal(f.provider.count(), 1);
});
