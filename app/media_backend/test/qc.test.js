// Pure QC tests plus one local-ffmpeg integration pass (lavfi fixtures,
// no network, no provider calls).
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, readFileSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { qcFileIntegrity, qcDuration, qcResolution, qcAudio, qcSegmentCoverage, qcExportCompleteness, summarizeQc } from '../src/qc.js';
import { Timeline, masterMedia, scene } from '../src/timeline.js';
import { runProcess, FfmpegRenderer } from '../src/render.js';
import { runProcessCapture, measureLoudness } from '../src/ffmpeg_ops.js';

const sha = value => createHash('sha256').update(value).digest('hex');

test('file integrity compares size and hash against the artifact receipt', () => {
  const digest = sha('bytes');
  assert.equal(qcFileIntegrity({ actualByteSize: 10, actualSha256: digest, expectedByteSize: 10, expectedSha256: digest }).status, 'pass');
  assert.equal(qcFileIntegrity({ actualByteSize: 10, actualSha256: digest, expectedByteSize: 11, expectedSha256: digest }).status, 'fail');
  assert.equal(qcFileIntegrity({ actualByteSize: 10, actualSha256: digest, expectedByteSize: 10, expectedSha256: sha('other') }).status, 'fail');
  assert.equal(qcFileIntegrity({ actualByteSize: 0, actualSha256: digest, expectedByteSize: 0, expectedSha256: digest }).status, 'fail');
});

test('duration and resolution checks use the export plan as expected values', () => {
  assert.equal(qcDuration({ actualSeconds: 64.8, expectedSeconds: 65, toleranceSeconds: 0.5 }).status, 'pass');
  assert.equal(qcDuration({ actualSeconds: 60, expectedSeconds: 65, toleranceSeconds: 0.5 }).status, 'fail');
  assert.equal(qcResolution({ actualWidth: 1080, actualHeight: 1920, expectedWidth: 1080, expectedHeight: 1920 }).status, 'pass');
  const failed = qcResolution({ actualWidth: 1280, actualHeight: 720, expectedWidth: 1080, expectedHeight: 1920 });
  assert.equal(failed.status, 'fail');
  assert.deepEqual(failed.details, { actual: '1280x720', expected: '1080x1920' });
});

test('audio check covers presence and measured loudness bounds', () => {
  const streams = [{ codec_type: 'video', codec_name: 'h264' }, { codec_type: 'audio', codec_name: 'aac', channels: 2, sample_rate: '44100' }];
  assert.equal(qcAudio({ streams }).status, 'pass');
  assert.equal(qcAudio({ streams, loudness: { inputI: -16.2 } }).status, 'pass');
  assert.equal(qcAudio({ streams, loudness: { inputI: -55 } }).status, 'fail');
  const missing = qcAudio({ streams: [{ codec_type: 'video' }] });
  assert.equal(missing.status, 'fail');
  assert.equal(qcAudio({ streams: [{ codec_type: 'video' }], requireAudio: false }).status, 'na');
});

test('segment coverage reports gaps and overlaps for selective repair', () => {
  const good = qcSegmentCoverage({ segments: [
    { id: 's1', startSeconds: 0, endSeconds: 30 }, { id: 's2', startSeconds: 30, endSeconds: 65 } ], masterDurationSeconds: 65 });
  assert.equal(good.status, 'pass');
  const gapped = qcSegmentCoverage({ segments: [
    { id: 's1', startSeconds: 0, endSeconds: 30 }, { id: 's2', startSeconds: 40, endSeconds: 65 } ], masterDurationSeconds: 65 });
  assert.equal(gapped.status, 'fail');
  assert.deepEqual(gapped.details.gaps, [{ from: 30, to: 40, id: 's2' }]);
  const overlapped = qcSegmentCoverage({ segments: [
    { id: 's1', startSeconds: 0, endSeconds: 35 }, { id: 's2', startSeconds: 30, endSeconds: 65 } ], masterDurationSeconds: 65 });
  assert.equal(overlapped.status, 'fail');
  assert.equal(overlapped.details.overlaps.length, 1);
  const tail = qcSegmentCoverage({ segments: [{ id: 's1', startSeconds: 0, endSeconds: 60 }], masterDurationSeconds: 65 });
  assert.equal(tail.status, 'fail');
  assert.deepEqual(tail.details.gaps, [{ from: 60, to: 65, id: null }]);
});

test('segment coverage accepts a real timeline export plan', () => {
  const timeline = new Timeline();
  const master = timeline.addMaster(masterMedia({ artifactId: 'a1', durationSeconds: 90 }));
  timeline.addScene(scene({ masterId: master.id, index: 0, startSeconds: 0, endSeconds: 45 }));
  timeline.addScene(scene({ masterId: master.id, index: 1, startSeconds: 45, endSeconds: 90 }));
  const result = qcSegmentCoverage({ segments: timeline.ordered('scene'), masterDurationSeconds: master.durationSeconds });
  assert.equal(result.status, 'pass');
  assert.equal(result.details.segmentCount, 2);
});

test('export completeness requires every planned artifact with hash and size', () => {
  const artifacts = [
    { id: 'master', sha256: sha('m'), byteSize: 100 },
    { id: 'reel', sha256: sha('r'), byteSize: 50 },
    { id: 'draft', sha256: sha('d'), byteSize: 10 },
  ];
  assert.equal(qcExportCompleteness({ expectedArtifactIds: ['master', 'reel'], artifacts }).status, 'pass');
  const missing = qcExportCompleteness({ expectedArtifactIds: ['master', 'thumb'], artifacts });
  assert.equal(missing.status, 'fail');
  assert.deepEqual(missing.details.missing, ['thumb']);
  const invalid = qcExportCompleteness({ expectedArtifactIds: ['master', 'reel'],
    artifacts: [{ id: 'master', sha256: sha('m'), byteSize: 100 }, { id: 'reel', sha256: 'nope', byteSize: 50 }] });
  assert.equal(invalid.status, 'fail');
  assert.deepEqual(invalid.details.invalid, ['reel']);
});

test('summarizeQc folds checks into a pass/fail report', () => {
  const report = summarizeQc('reel-1', [
    qcDuration({ actualSeconds: 65, expectedSeconds: 65 }),
    qcResolution({ actualWidth: 1080, actualHeight: 1920, expectedWidth: 1080, expectedHeight: 1920 }),
    qcAudio({ streams: [{ codec_type: 'video' }] }),
  ]);
  assert.equal(report.status, 'fail');
  assert.deepEqual(report.failedChecks, ['audio']);
  assert.equal(report.artifactId, 'reel-1');
  assert.ok(report.checkedAt);
  const passing = summarizeQc('reel-1', [qcDuration({ actualSeconds: 65, expectedSeconds: 65 })]);
  assert.equal(passing.status, 'pass');
  assert.deepEqual(passing.failedChecks, []);
});

test('qc runs end-to-end on a locally rendered clip (no network)', async t => {
  const root = mkdtempSync(join(tmpdir(), 'ovexiq-qc-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const file = join(root, 'clip.mp4');
  await runProcess('ffmpeg', ['-nostdin', '-v', 'error', '-f', 'lavfi', '-i', 'testsrc=size=1080x1920:rate=25:duration=5',
    '-f', 'lavfi', '-i', 'sine=frequency=440:duration=5', '-c:v', 'libx264', '-preset', 'veryfast', '-pix_fmt', 'yuv420p',
    '-c:a', 'aac', '-shortest', '-movflags', '+faststart', file], 120000);
  const bytes = readFileSync(file);
  const renderer = new FfmpegRenderer();
  const info = await renderer.probe(file);
  const video = info.streams.find(s => s.codec_type === 'video');
  const loudness = await measureLoudness({ file });
  const report = summarizeQc('clip-1', [
    qcFileIntegrity({ actualByteSize: statSync(file).size, actualSha256: sha(bytes), expectedByteSize: bytes.length, expectedSha256: sha(bytes) }),
    qcDuration({ actualSeconds: Number(info.format.duration), expectedSeconds: 5 }),
    qcResolution({ actualWidth: video.width, actualHeight: video.height, expectedWidth: 1080, expectedHeight: 1920 }),
    qcAudio({ streams: info.streams, loudness }),
  ]);
  assert.equal(report.status, 'pass', JSON.stringify(report.failedChecks));
});
