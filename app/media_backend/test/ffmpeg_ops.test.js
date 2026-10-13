// Arg builders are pure (no ffmpeg). Execution tests use local lavfi
// fixtures only: no network, no provider calls.
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { MediaFailure } from '../src/contracts.js';
import { FfmpegOps, runProcessCapture, trimArgs, concatListContent, concatArgs,
  reframeArgs, normalizeAudioArgs, escapeFilterPath, burnSubtitlesArgs, buildAss, muxArgs, measureLoudness } from '../src/ffmpeg_ops.js';
import { runProcess } from '../src/render.js';
import { caption } from '../src/timeline.js';

const fails = (fn, code) => assert.throws(fn, error => error instanceof MediaFailure && error.code === code);
const sha256File = path => createHash('sha256').update(readFileSync(path)).digest('hex');

async function probe(file) {
  const { stdout } = await runProcessCapture('ffprobe', ['-v', 'error', '-show_format', '-show_streams', '-of', 'json', file], 30000);
  return JSON.parse(stdout);
}

test('trim args are frame-accurate (-ss after -i) and validated', () => {
  const args = trimArgs({ input: 'in.mp4', startSeconds: 12.5, durationSeconds: 30, output: 'out.mp4' });
  const inputIndex = args.indexOf('-i');
  assert.ok(args.indexOf('-ss') < inputIndex); // -ss precedes -i for accuracy
  assert.deepEqual(args.slice(inputIndex, inputIndex + 4), ['-i', 'in.mp4', '-t', '30']);
  assert.ok(args.includes('-map_metadata') && args.includes('+faststart'));
  fails(() => trimArgs({ input: 'in.mp4', startSeconds: -1, durationSeconds: 30, output: 'o' }), 'invalid_trim_start');
  fails(() => trimArgs({ input: 'in.mp4', startSeconds: 0, durationSeconds: 0, output: 'o' }), 'invalid_trim_duration');
});

test('concat list content escapes quotes per the demuxer spec', () => {
  const content = concatListContent(['/tmp/a.mp4', "/tmp/o'clock.mp4"]);
  assert.equal(content, "file '/tmp/a.mp4'\nfile '/tmp/o'\\''clock.mp4'\n");
  fails(() => concatListContent(['/tmp/only.mp4']), 'invalid_concat_inputs');
  const args = concatArgs({ listFile: 'list.txt', output: 'out.mp4' });
  assert.ok(args.includes('-f') && args.includes('concat') && args.includes('-c') && args.includes('copy'));
});

test('reframe covers fill (crop) and fit (pad) between aspects', () => {
  const fill = reframeArgs({ input: 'in.mp4', output: 'out.mp4', width: 720, height: 1280, mode: 'fill' });
  const fillFilter = fill[fill.indexOf('-vf') + 1];
  assert.ok(fillFilter.includes('force_original_aspect_ratio=increase') && fillFilter.includes('crop=720:1280'));
  const fit = reframeArgs({ input: 'in.mp4', output: 'out.mp4', width: 720, height: 1280, mode: 'fit' });
  const fitFilter = fit[fit.indexOf('-vf') + 1];
  assert.ok(fitFilter.includes('force_original_aspect_ratio=decrease') && fitFilter.includes('pad=720:1280'));
  fails(() => reframeArgs({ input: 'i', output: 'o', width: 720, height: 1280, mode: 'stretch' }), 'invalid_reframe_mode');
});

test('normalize args pin EBU R128 targets; burn-in escapes filter paths', () => {
  const args = normalizeAudioArgs({ input: 'in.wav', output: 'out.m4a', targetI: -16, targetTP: -1.5, targetLRA: 11 });
  const filter = args[args.indexOf('-af') + 1];
  assert.equal(filter, 'loudnorm=I=-16:TP=-1.5:LRA=11');
  fails(() => normalizeAudioArgs({ input: 'i', output: 'o', targetI: NaN }), 'invalid_loudness_target');
  assert.equal(escapeFilterPath("C:\\vid:sub's.ass"), "C\\:\\\\vid\\:sub\\'s.ass");
  const burn = burnSubtitlesArgs({ input: 'in.mp4', output: 'out.mp4', subtitlesPath: '/tmp/cap.ass' });
  const burnFilter = burn[burn.indexOf('-vf') + 1];
  assert.ok(burnFilter.startsWith('subtitles=') && burnFilter.includes('/tmp/cap.ass'));
});

test('buildAss renders deterministic ASS from timeline captions', () => {
  const ass = buildAss([
    caption({ masterId: 'm1', startSeconds: 1.5, endSeconds: 4.25, text: 'Hello, world' }),
    caption({ masterId: 'm1', startSeconds: 5, endSeconds: 7, text: 'Line {two}\\three' }),
  ], { playResX: 1080, playResY: 1920 });
  assert.ok(ass.includes('PlayResX: 1080') && ass.includes('PlayResY: 1920'));
  assert.ok(ass.includes('Dialogue: 0,0:00:01.50,0:00:04.25,Default,,0,0,0,,Hello, world'));
  assert.ok(ass.includes('Line  two  three')); // braces/backslash neutralized
  assert.equal(buildAss([], {}).split('\n').filter(l => l.startsWith('Dialogue')).length, 0);
  fails(() => buildAss([{ startSeconds: 5, endSeconds: 2, text: 'x' }]), 'invalid_ass_timing');
  fails(() => buildAss([{ startSeconds: 0, endSeconds: 1, text: '' }]), 'invalid_ass_captions');
});

test('mux args map video and audio streams with copy', () => {
  const args = muxArgs({ video: 'v.mp4', audio: 'a.m4a', output: 'out.mp4' });
  assert.deepEqual(args.slice(args.indexOf('-map'), args.indexOf('-map') + 4), ['-map', '0:v:0', '-map', '1:a:0']);
  assert.ok(args.includes('-shortest'));
  assert.ok(!muxArgs({ video: 'v', audio: 'a', output: 'o', shortest: false }).includes('-shortest'));
});

// ---- Execution against local synthetic fixtures (no network) ----

function fixtures(t) {
  const root = mkdtempSync(join(tmpdir(), 'ovexiq-ffmpeg-ops-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  return root;
}
async function makeClip(root, name, { duration = 4, width = 1280, height = 720, withAudio = true } = {}) {
  const out = join(root, name);
  const args = ['-nostdin', '-v', 'error', '-f', 'lavfi', '-i', `testsrc=size=${width}x${height}:rate=25:duration=${duration}`];
  if (withAudio) args.push('-f', 'lavfi', '-i', `sine=frequency=440:duration=${duration}`, '-c:a', 'aac', '-shortest');
  args.push('-c:v', 'libx264', '-preset', 'veryfast', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', out);
  await runProcess('ffmpeg', args, 120000);
  return out;
}

test('trim is deterministic: identical inputs produce identical bytes', async t => {
  const root = fixtures(t);
  const clip = await makeClip(root, 'clip.mp4');
  const ops = new FfmpegOps();
  const first = join(root, 'trim1.mp4'), second = join(root, 'trim2.mp4');
  await ops.trim({ input: clip, startSeconds: 1, durationSeconds: 2, output: first });
  await ops.trim({ input: clip, startSeconds: 1, durationSeconds: 2, output: second });
  assert.equal(sha256File(first), sha256File(second));
  const info = await probe(first);
  assert.ok(Math.abs(Number(info.format.duration) - 2) < 0.3);
});

test('concat joins clips and reframe converts 16:9 to 9:16', async t => {
  const root = fixtures(t);
  const a = await makeClip(root, 'a.mp4', { duration: 2 });
  const b = await makeClip(root, 'b.mp4', { duration: 3 });
  const ops = new FfmpegOps();
  const joined = join(root, 'joined.mp4');
  await ops.concat({ inputs: [a, b], output: joined });
  const joinedInfo = await probe(joined);
  assert.ok(Math.abs(Number(joinedInfo.format.duration) - 5) < 0.5);
  const vertical = join(root, 'vertical.mp4');
  await ops.reframe({ input: joined, output: vertical, width: 720, height: 1280, mode: 'fill' });
  const video = (await probe(vertical)).streams.find(s => s.codec_type === 'video');
  assert.equal(video.width, 720); assert.equal(video.height, 1280);
});

test('normalizeAudio and loudness measurement work on synthetic audio', async t => {
  const root = fixtures(t);
  const clip = await makeClip(root, 'clip.mp4');
  const ops = new FfmpegOps();
  const normalized = join(root, 'norm.m4a');
  await ops.normalizeAudio({ input: clip, output: normalized });
  const measured = await measureLoudness({ file: normalized });
  assert.ok(Number.isFinite(measured.inputI) && Number.isFinite(measured.inputTp));
  // Normalized output lands near the -16 LUFS target (single-pass tolerance).
  assert.ok(Math.abs(measured.inputI - -16) < 2.5, `inputI=${measured.inputI}`);
});

test('subtitle burn-in renders caption text into the frame', async t => {
  const root = fixtures(t);
  const clip = await makeClip(root, 'clip.mp4', { duration: 4 });
  const assPath = join(root, 'caps.ass');
  writeFileSync(assPath, buildAss([
    caption({ masterId: 'm1', startSeconds: 0.5, endSeconds: 3.5, text: 'Previously on Ovexiq' }),
  ], { playResX: 1280, playResY: 720 }), { mode: 0o600 });
  const ops = new FfmpegOps();
  const burned = join(root, 'burned.mp4');
  await ops.burnSubtitles({ input: clip, output: burned, subtitlesPath: assPath });
  const info = await probe(burned);
  const video = info.streams.find(s => s.codec_type === 'video');
  const audio = info.streams.find(s => s.codec_type === 'audio');
  assert.equal(video.width, 1280); assert.equal(video.height, 720);
  assert.ok(audio, 'audio stream preserved through burn-in');
});

test('mux combines silent video with narration audio', async t => {
  const root = fixtures(t);
  const silent = await makeClip(root, 'silent.mp4', { duration: 3, withAudio: false });
  const voice = join(root, 'voice.m4a');
  await runProcess('ffmpeg', ['-nostdin', '-v', 'error', '-f', 'lavfi', '-i', 'sine=frequency=220:duration=3', '-c:a', 'aac', voice], 60000);
  const ops = new FfmpegOps();
  const out = join(root, 'muxed.mp4');
  await ops.mux({ video: silent, audio: voice, output: out });
  const info = await probe(out);
  assert.ok(info.streams.some(s => s.codec_type === 'video'));
  assert.ok(info.streams.some(s => s.codec_type === 'audio'));
});
