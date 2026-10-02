import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { FfmpegRenderer, runProcess } from '../src/render.js';

// Explicit opt-in: synthetic color cards and a sine wave only, no paid provider.
// Run inside the same Linux container image used by the server.
test('real FFmpeg full-song and portrait teaser encode/decode', { skip: process.env.MEDIA_RENDER_SMOKE !== '1' }, async t => {
  const root = mkdtempSync(join(tmpdir(), 'ovexiq-render-smoke-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const renderer = new FfmpegRenderer(); await renderer.preflight();
  const images = [];
  for (const [index, color] of ['red', 'green', 'blue', 'gray'].entries()) {
    const file = join(root, `${index}.jpg`); images.push(file);
    await runProcess('ffmpeg', ['-nostdin', '-v', 'error', '-f', 'lavfi', '-i', `color=c=${color}:s=1280x720`, '-frames:v', '1', '-threads', '1', file]);
  }
  const audio = join(root, 'song.mp3');
  await runProcess('ffmpeg', ['-nostdin', '-v', 'error', '-f', 'lavfi', '-i', 'sine=frequency=220:sample_rate=44100', '-t', '48', '-c:a', 'libmp3lame', audio]);
  const duration = await renderer.validateAudio(audio);
  assert.ok(duration >= 48 && duration < 49);
  for (const [width, height, seconds, start] of [[1280, 720, duration, 0], [720, 1280, 30, 12]]) {
    const output = join(root, `${width}.mp4`);
    const result = await renderer.export({ images, audio, output, width, height, duration: seconds, start });
    assert.equal(result.videoCodec, 'h264'); assert.equal(result.audioCodec, 'aac');
    assert.equal(result.width, width); assert.equal(result.height, height);
    assert.ok(Math.abs(result.durationSeconds - seconds) < 0.5);
  }
});
