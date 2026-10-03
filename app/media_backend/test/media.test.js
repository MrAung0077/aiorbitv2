import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { MediaStore, publicProject } from '../src/store.js';
import { MediaFailure, defaultArtist, validateSpec, musicPrompt, songSpecInstruction } from '../src/contracts.js';
import { SongSpecProvider, LyriaMusicProvider } from '../src/providers.js';
import { SongWorkflow } from '../src/workflow.js';
import { FfmpegRenderer, renderArguments } from '../src/render.js';
import { mediaServer } from '../src/server.js';

const owner = `acct_${randomUUID()}`;
const spec = (language = 'en') => ({ title: 'Morning', theme: 'a new beginning', genre: 'soft rock', mood: 'hopeful',
  tempoDirection: '90 BPM', instrumentation: 'guitar, drums', vocalCharacteristics: 'warm baritone',
  structure: 'verse chorus bridge outro', language, chorusStartSeconds: 40,
  lyrics: language === 'my' ? '[Verse 1]\nမနက်ခင်း အလင်းရောင်\n[Chorus]\nနေ့သစ်ကို ကြိုဆိုမယ်' : '[Verse 1]\nMorning comes\n[Chorus]\nWe begin again' });
function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), 'ovexiq-media-test-'));
  const store = new MediaStore(root);
  t.after(() => { store.close(); rmSync(root, { recursive: true, force: true }); });
  const ids = Array.from({ length: 4 }, () => randomUUID());
  ids.forEach(id => store.addVisual(owner, id, join(root, `${id}.jpg`), { width: 1920, height: 1080 }));
  store.saveArtist(owner, { artistName: 'Ari', visualReferenceIds: ids });
  return store;
}
const input = (language = 'en') => ({ goal: language === 'my' ? 'မြန်မာလို slow rock သီချင်းတစ်ပုဒ်လုပ်ပေး' : 'Create an original English soft-rock song', language, requestId: randomUUID() });
function fakes(store, overrides = {}) {
  const calls = { text: 0, music: 0, renders: [] };
  const workflow = new SongWorkflow({ store,
    textProvider: { async create(_goal, language) { calls.text++; return spec(language); } },
    musicProvider: { supportsLanguage: l => ['en', 'my'].includes(l), async generateSong(value, artist) {
      calls.music++; assert.match(value.lyrics, /\[Chorus\]/); assert.equal(artist.artistName, 'Ari');
      return { bytes: Buffer.alloc(256, 1), metadata: { model: 'mock' } };
    } },
    renderer: { async preflight() {}, async validateAudio() { return 150; }, async export(args) {
      calls.renders.push(args); writeFileSync(args.output, Buffer.alloc(256, 2));
      return { width: args.width, height: args.height, durationSeconds: args.duration, videoCodec: 'h264', audioCodec: 'aac' };
    } }, ...overrides });
  return { workflow, calls };
}

for (const language of ['en', 'my']) test(`${language}: persisted complete project, MP3 and both MP4s; no replay`, async t => {
  const store = fixture(t), request = input(language), project = store.create(owner, request);
  const { workflow, calls } = fakes(store);
  assert.equal(store.create(owner, request).projectId, project.projectId);
  await workflow.run(project); await workflow.run(project);
  const saved = store.get(owner, project.projectId);
  assert.equal(saved.status, 'completed'); assert.equal(saved.language, language);
  assert.deepEqual(saved.artifacts.map(a => a.fileName), ['lyrics.txt', 'song.mp3', 'youtube.mp4', 'teaser.mp4']);
  assert.equal(calls.text, 1); assert.equal(calls.music, 1);
  assert.equal(calls.renders[0].duration, 150); assert.equal(calls.renders[0].start, 0);
  assert.equal(calls.renders[0].width, 1920); assert.equal(calls.renders[0].height, 1080);
  assert.equal(calls.renders[1].duration, 30); assert.equal(calls.renders[1].start, 40);
  assert.equal(calls.renders[1].width, 1080); assert.equal(calls.renders[1].height, 1920);
  assert.equal(saved.videoArtifacts[1].aspectRatio, '9:16');
  assert.match(saved.videoArtifacts[1].selection, /requires_listening_review/);
  assert.ok(saved.artifacts.every(a => /^[a-f0-9]{64}$/.test(a.sha256) && a.byteSize > 0));
  assert.equal(store.get(`acct_${randomUUID()}`, project.projectId), null);
  assert.equal(publicProject(saved).owner, undefined); assert.equal(publicProject(saved).providerMetadata, undefined);
  assert.equal(saved.manifest.finalApproval.state, 'pending');
  assert.equal(saved.manifest.finalLyricsSource.source, 'generated');
  assert.equal(saved.manifest.finalSelectedVersions.length, 4);
  assert.equal(saved.manifest.assets.filter(a => a.kind === 'video').length, 2);
  assert.equal(publicProject(saved).manifest, undefined);
  assert.equal(publicProject(saved).provenance, undefined);
  assert.doesNotMatch(JSON.stringify(publicProject(saved)), /"path":|file:\/\/|[A-Z]:\\/);
  assert.doesNotMatch(JSON.stringify(publicProject(saved)), /continue this in|open Kits|https:\/\//i);
  const again = store.create(owner, input(language));
  assert.deepEqual(again.artist, project.artist);
});

test('admission caps, idempotency conflicts, ownership and uncertain restart', t => {
  const store = fixture(t), request = input(), project = store.create(owner, request);
  assert.throws(() => store.create(owner, { ...request, goal: 'Different original song' }), /idempotency_conflict/);
  assert.throws(() => store.create(owner, input()), /media_job_active/);
  assert.throws(() => store.saveArtist('other', project.artist), /invalid_visual/);
  project.status = 'generating'; store.save(project); store.interruptUncertain();
  assert.equal(store.get(owner, project.projectId).status, 'interrupted'); assert.equal(store.next(), undefined);
  const second = store.create(owner, input()); second.status = 'failed'; store.save(second);
  assert.throws(() => store.create(owner, input()), /media_daily_limit/);
  const reopened = new MediaStore(store.root);
  assert.equal(reopened.list(owner).length, 2); assert.equal(reopened.artist(owner).artistName, 'Ari'); reopened.close();
});

test('typed provider failure preserves lyrics, never exposes raw error or retries', async t => {
  const store = fixture(t), project = store.create(owner, input()); let calls = 0;
  const { workflow } = fakes(store, { musicProvider: { supportsLanguage: () => true, async generateSong() {
    calls++; throw new MediaFailure('provider_timeout_unknown', 'music');
  } } });
  await workflow.run(project); await workflow.run(project);
  assert.equal(calls, 1); assert.equal(project.status, 'failed');
  assert.deepEqual(project.failure, { code: 'provider_timeout_unknown', stage: 'music' });
  assert.deepEqual(project.artifacts.map(a => a.fileName), ['lyrics.txt']);
});

test('render failure preserves accepted MP3; preflight failure makes no paid call', async t => {
  const store = fixture(t), project = store.create(owner, input());
  const { workflow, calls } = fakes(store);
  workflow.renderer.export = async () => { throw new Error('private provider content'); };
  await workflow.run(project);
  assert.equal(project.status, 'failed'); assert.equal(project.audioArtifact.mimeType, 'audio/mpeg');
  assert.doesNotMatch(JSON.stringify(project.failure), /private/);
  const second = store.create(owner, input());
  workflow.renderer.preflight = async () => { throw new MediaFailure('ffmpeg_unavailable', 'render'); };
  await workflow.run(second); assert.equal(calls.music, 1); assert.equal(calls.text, 1);
});

test('official Lyria request uses exact lyrics, fixed fictional voice and safe metadata', async () => {
  let count = 0;
  const provider = new LyriaMusicProvider({ apiKey: 'synthetic-test-key', fetcher: async (url, init) => {
    count++; assert.equal(url, 'https://generativelanguage.googleapis.com/v1beta/models/lyria-3.5:generateContent');
    const text = JSON.parse(init.body).contents[0].parts[0].text;
    assert.ok(text.includes(spec('my').lyrics)); assert.ok(text.includes(defaultArtist.vocalProfile));
    assert.equal(init.headers['x-goog-api-key'], 'synthetic-test-key');
    return Response.json({ candidates: [{ finishReason: 'STOP', content: { parts: [{ inlineData: {
      mimeType: 'audio/mpeg', data: Buffer.alloc(256, 1).toString('base64'),
    } }] } }], responseId: 'safe-id', usageMetadata: { totalTokenCount: 100 } });
  } });
  const result = await provider.generateSong(spec('my'), defaultArtist);
  assert.equal(count, 1); assert.equal(result.bytes.length, 256);
  assert.equal(provider.capabilities.voiceIdentityGuaranteed, false);
  assert.doesNotMatch(JSON.stringify(result.metadata), /synthetic-test-key/);
});

for (const failure of ['rate', 'json', 'empty', 'transport', 'timeout']) test(`music ${failure} fails once, sanitized`, async () => {
  let count = 0;
  const provider = new LyriaMusicProvider({ apiKey: 'synthetic-test-key', fetcher: async () => {
    count++;
    if (failure === 'rate') return new Response('private upstream body', { status: 429 });
    if (failure === 'json') return new Response('private malformed body');
    if (failure === 'empty') return Response.json({});
    const error = new Error('private synthetic-test-key'); if (failure === 'timeout') error.name = 'TimeoutError'; throw error;
  } });
  await assert.rejects(provider.generateSong(spec(), defaultArtist), error => {
    assert.ok(error instanceof MediaFailure); assert.doesNotMatch(JSON.stringify(error), /private|synthetic-test-key/); return true;
  }); assert.equal(count, 1);
});

test('song spec has separate lyric quality rules and no arbitrary response fields', async () => {
  assert.match(songSpecInstruction('my', defaultArtist), /singable Burmese/);
  assert.match(songSpecInstruction('en', defaultArtist), /natural English/);
  assert.ok(musicPrompt(spec(), defaultArtist).includes(spec().lyrics));
  assert.throws(() => validateSpec(spec(), 'my'), /invalid_lyric_language/);
  const provider = new SongSpecProvider({ apiKey: 'mock', fetcher: async (_url, init) => {
    assert.equal(JSON.parse(init.body).max_tokens, 4096);
    return Response.json({ choices: [{ finish_reason: 'stop', message: { content: JSON.stringify({ ...spec(), unexpected: 'omit' }) } }] });
  } });
  assert.equal((await provider.create('synthetic goal', 'en', defaultArtist)).unexpected, undefined);
});

test('final user lyrics are kept verbatim even when generated specification rewrites them', async () => {
  const lyrics = '  မနက်ခင်း အလင်းရောင်\nနေ့သစ်ကို ကြိုဆိုမယ်  ';
  const provider = new SongSpecProvider({ apiKey: 'mock', fetcher: async (_url, init) => {
    const request = JSON.parse(init.body);
    assert.equal(JSON.parse(request.messages[1].content).finalLyrics, lyrics);
    assert.match(request.messages[0].content, /Preserve them verbatim/);
    return Response.json({ choices: [{ finish_reason: 'stop', message: { content: JSON.stringify(spec('my')) } }] });
  } });
  const result = await provider.create('synthetic goal', 'my', defaultArtist, { userFinalLyrics: lyrics, style: 'slow rock' });
  assert.equal(result.lyrics, lyrics);
});

for (const preferences of [
  { voiceIntent: 'reusable_identity' },
  { voiceIntent: 'own_voice_clone', voicePermissionConfirmed: true },
  { voiceIntent: 'custom_locked_voice', voicePermissionConfirmed: true },
  { subtitles: 'requested' },
]) test(`unavailable ${JSON.stringify(preferences)} stops before any paid stage, without replay`, async t => {
  const store = fixture(t), project = store.create(owner, { ...input(), preferences });
  const { workflow, calls } = fakes(store);
  await workflow.run(project); await workflow.run(project);
  assert.equal(project.status, 'failed'); assert.equal(project.failure.stage, 'preflight');
  assert.equal(calls.text, 0); assert.equal(calls.music, 0); assert.equal(calls.renders.length, 0);
  assert.equal(project.artifacts.length, 0);
});

for (const voiceIntent of ['generated', 'reusable_identity', 'own_voice_clone', 'custom_locked_voice']) {
  test(`mock ${voiceIntent} workflow passes full intent and invokes optional voice only as requested`, async t => {
    const store = fixture(t);
    const preferences = { voiceIntent, context: 'album', style: 'slow rock', voicePermissionConfirmed: true,
      userFinalLyrics: '  Final user lyrics\nKeep them exactly  ' };
    const request = { ...input(), preferences }, project = store.create(owner, request);
    let musicCalls = 0, voiceCalls = 0;
    const { workflow } = fakes(store, {
      musicProvider: { providerId: 'mock-music', capabilities: { reusableSingerIdentity: true, customLyrics: true },
        supportsLanguage: () => true, async generateSong(value, artist, requirement) {
          musicCalls++; assert.equal(value.lyrics, preferences.userFinalLyrics); assert.equal(value.genre, preferences.style);
          assert.equal(requirement.voiceIntent, voiceIntent); assert.equal(requirement.context, 'album');
          assert.equal(artist.artistName, 'Ari');
          return { bytes: Buffer.alloc(256, 1), metadata: { provider: 'mock-music' } };
        } },
      voiceCandidates: [{ provider: { providerId: 'mock-voice', capabilities: { languages: ['en', 'my'] },
        supportsVoiceMode: mode => ['own_voice_clone', 'custom_locked_voice'].includes(mode),
        async convertOrClone(audio, requirement) {
          voiceCalls++; assert.equal(requirement.voiceIntent, voiceIntent); assert.equal(requirement.artist.artistName, 'Ari');
          return audio;
        } } }],
    });
    await workflow.run(project); await workflow.run(project);
    assert.equal(project.status, 'completed'); assert.equal(musicCalls, 1);
    assert.equal(voiceCalls, ['own_voice_clone', 'custom_locked_voice'].includes(voiceIntent) ? 1 : 0);
    assert.equal(project.lyrics, preferences.userFinalLyrics);
    assert.equal(store.create(owner, request).projectId, project.projectId);
    assert.throws(() => store.create(owner, { ...request, preferences: { ...preferences, subtitles: 'requested' } }), /idempotency_conflict/);
    const reopened = new MediaStore(store.root);
    assert.equal(reopened.get(owner, project.projectId).preferences.voiceIntent, voiceIntent); reopened.close();
  });
}

test('old persisted projects without preferences retain original defaults and idempotency', t => {
  const store = fixture(t), request = input(), project = store.create(owner, request);
  delete project.preferences; store.save(project);
  assert.equal(store.create(owner, request).projectId, project.projectId);
});

test('commercial project input cannot forge rights, provenance, approval or idempotency', async t => {
  const store = fixture(t), request = { ...input(), commercialUseRequested: true,
    preferences: { userFinalLyrics: '[Verse]\nUser lyrics\n[Chorus]\nUser chorus' },
    provenance: { assets: [{ rights: { commercialUseStatus: 'allowed' } }], finalApproval: { state: 'approved' } },
    manifest: { commercialReadiness: { status: 'COMMERCIAL_READY' } } };
  const project = store.create(owner, request);
  const { workflow, calls } = fakes(store, { musicProvider: { capabilities: { customLyrics: true }, supportsLanguage: () => true,
    async generateSong() { return { bytes: Buffer.alloc(256, 1), metadata: { commercialUseStatus: 'allowed' } }; } } });
  await workflow.run(project);
  const saved = store.get(owner, project.projectId);
  assert.equal(saved.manifest.commercialReadiness.status, 'COMMERCIAL_REVIEW_REQUIRED');
  assert.equal(saved.manifest.finalLyricsSource.source, 'user');
  assert.equal(saved.manifest.finalApproval.state, 'pending');
  assert.equal(calls.text, 1);
  assert.throws(() => store.create(owner, { ...request, commercialUseRequested: false }), /idempotency_conflict/);
  const approved = store.approve(owner, project.projectId, { action: 'approve_final', selectedArtifactIds: saved.artifacts.map(a => a.id),
    commercialUseStatus: 'allowed' });
  assert.equal(approved.manifest.finalApproval.state, 'approved');
  assert.equal(approved.manifest.commercialReadiness.status, 'COMMERCIAL_REVIEW_REQUIRED');
  const reopened = new MediaStore(store.root);
  assert.deepEqual(reopened.get(owner, project.projectId).manifest, approved.manifest); reopened.close();
  assert.throws(() => store.approve(`acct_${randomUUID()}`, project.projectId, { action: 'approve_final' }), /not_found/);
});

for (const voiceIntent of ['own_voice_clone', 'custom_locked_voice']) {
  test(`verified voice terms apply before generation: ${voiceIntent}`, async t => {
    t.mock.timers.enable({ apis: ['Date'], now: new Date('2026-10-03T12:00:00Z') });
    const store = fixture(t), project = store.create(owner, { ...input(), commercialUseRequested: true,
      preferences: { voiceIntent, voicePermissionConfirmed: true } });
    let voiceCalls = 0;
    const voice = { providerId: 'suno', capabilities: { languages: ['en'] }, supportsVoiceMode: () => true,
      rightsContext: { product: 'music_service', plan: 'pro', generationMode: 'voice_model_output',
        subscribedAtGeneration: true, downloadedThroughApprovedChannel: true },
      async convertOrClone(audio) { voiceCalls++; return audio; } };
    const { workflow, calls } = fakes(store, { voiceCandidates: [{ provider: voice }] });
    await workflow.run(project);
    if (voiceIntent === 'custom_locked_voice') {
      assert.equal(project.status, 'failed'); assert.equal(project.failure.code, 'voice_rights_incompatible');
      assert.equal(calls.text, 0); assert.equal(calls.music, 0); assert.equal(voiceCalls, 0);
    } else {
      assert.equal(project.status, 'completed'); assert.equal(voiceCalls, 1);
      const audio = project.manifest.assets.find(a => a.id === project.audioArtifact.id);
      assert.equal(audio.rights.matchingRuleId, 'suno-paid-output-20260903');
      assert.equal(audio.rights.verification.evidence.rules.length, 2);
      const saved = JSON.stringify(store.get(owner, project.projectId).manifest);
      voice.rightsContext.plan = 'basic';
      assert.equal(JSON.stringify(store.get(owner, project.projectId).manifest), saved);
      assert.equal(project.manifest.commercialReadiness.status, 'COMMERCIAL_REVIEW_REQUIRED'); // Other sources remain unknown.
    }
  });
}

test('missing provider keys fail at their stage before any network call', async () => {
  let calls = 0;
  const fetcher = async () => { calls++; assert.fail('provider must not be called'); };
  const text = new SongSpecProvider({ fetcher });
  const music = new LyriaMusicProvider({ fetcher });
  await assert.rejects(text.create('synthetic goal', 'en', defaultArtist), error =>
    error instanceof MediaFailure && error.code === 'provider_not_configured' && error.stage === 'song_spec');
  await assert.rejects(music.generateSong(spec(), defaultArtist), error =>
    error instanceof MediaFailure && error.code === 'provider_not_configured' && error.stage === 'music');
  assert.equal(calls, 0);
});

test('FFmpeg full audio and teaser trims, codecs, fixed images and fades', async () => {
  const options = { images: ['1.jpg', '2.jpg', '3.jpg', '4.jpg'], audio: 'song.mp3', output: 'full.mp4', duration: 150, width: 1920, height: 1080 };
  const args = renderArguments(options); const filter = args[args.indexOf('-filter_complex') + 1];
  assert.match(filter, /atrim=start=0:duration=150/); assert.equal((filter.match(/xfade=/g) ?? []).length, 3);
  assert.match(filter, /zoompan/); assert.ok(args.includes('libx264')); assert.ok(args.includes('aac'));
  const teaser = renderArguments({ ...options, duration: 30, start: 40, width: 1080, height: 1920 });
  assert.ok(teaser.some(a => a.includes('atrim=start=40:duration=30')));
  const renderer = new FfmpegRenderer({ run: async () => JSON.stringify({ streams: [{ codec_type: 'audio', codec_name: 'wav' }], format: { duration: 150 } }) });
  await assert.rejects(renderer.validateAudio('not-mp3'), /invalid_song_audio/);
});

test('shared HTTP job/history/artifact contract is authenticated and owner-scoped', async t => {
  const store = fixture(t), { workflow } = fakes(store);
  const key = 'synthetic-service-key-for-tests-only';
  const server = mediaServer({ store, renderer: { async preflight() {} }, serviceKey: key });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}/v1/media`;
  const headers = { Authorization: `Bearer ${key}`, 'X-Ovexiq-Account': owner, 'Content-Type': 'application/json' };
  assert.equal((await fetch(`${base}/projects`)).status, 401);
  const request = input();
  const response = await fetch(`${base}/projects`, { method: 'POST', headers, body: JSON.stringify(request) });
  assert.equal(response.status, 202); const created = await response.json();
  const repeated = await (await fetch(`${base}/projects`, { method: 'POST', headers, body: JSON.stringify(request) })).json();
  assert.equal(created.projectId, repeated.projectId);
  await workflow.run(store.get(owner, created.projectId));
  const history = await (await fetch(`${base}/projects`, { headers })).json();
  assert.equal(history.projects[0].status, 'completed'); assert.equal(store.list(owner).length, 1);
  const artifact = history.projects[0].artifacts[0];
  const url = `${base}/projects/${created.projectId}/artifacts/${artifact.id}`;
  const file = await fetch(url, { headers });
  assert.equal(file.status, 200); assert.equal(file.headers.get('x-artifact-sha256'), artifact.sha256);
  assert.match(await file.text(), /\[Chorus\]/);
  assert.equal((await fetch(url, { headers: { ...headers, 'X-Ovexiq-Account': `acct_${randomUUID()}` } })).status, 404);
  const approvalUrl = `${base}/projects/${created.projectId}`;
  const approvalBody = JSON.stringify({ action: 'approve_final', selectedArtifactIds: history.projects[0].artifacts.map(a => a.id) });
  assert.equal((await fetch(approvalUrl, { method: 'PUT', body: approvalBody, headers: {
    ...headers, 'X-Ovexiq-Account': `acct_${randomUUID()}` } })).status, 404);
  const approved = await (await fetch(approvalUrl, { method: 'PUT', headers, body: approvalBody })).json();
  assert.equal(approved.provenanceSummary.finalApproval, 'approved');
  assert.equal(approved.manifest, undefined); assert.equal(approved.provenance, undefined);
  assert.equal(store.list(owner).length, 1);
});
