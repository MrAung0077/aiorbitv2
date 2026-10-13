// Selective, deterministic QC result model for narrative / recap exports.
//
// Lightweight structures (not AI judgement) for: file integrity, duration,
// resolution, audio presence/levels, expected segment coverage and export
// completeness. Every check is a pure function of caller-supplied data —
// typically ffprobe JSON, measured loudness (see ffmpeg_ops.measureLoudness)
// and the timeline model — so results are reproducible and testable without
// network access or paid providers.
//
// A check result is { name, status: 'pass' | 'fail' | 'na', details }.
// summarizeQc folds checks into { artifactId, status, failedChecks, ... }.

import { requireValue } from './contracts.js';

function number(value, code) {
  requireValue(typeof value === 'number' && Number.isFinite(value), code, 'qc_validation');
  return value;
}
function check(name, status, details = {}) {
  requireValue(['pass', 'fail', 'na'].includes(status), 'invalid_qc_status', 'qc_validation');
  return { name, status, details };
}

// Byte size and sha256 match the recorded artifact receipt.
export function qcFileIntegrity({ actualByteSize, actualSha256, expectedByteSize, expectedSha256 }) {
  number(actualByteSize, 'invalid_qc_size'); number(expectedByteSize, 'invalid_qc_size');
  requireValue(typeof actualSha256 === 'string' && typeof expectedSha256 === 'string', 'invalid_qc_hash', 'qc_validation');
  const ok = actualByteSize === expectedByteSize && actualByteSize > 0 && actualSha256 === expectedSha256;
  return check('file_integrity', ok ? 'pass' : 'fail',
    { actualByteSize, expectedByteSize, sha256Match: actualSha256 === expectedSha256 });
}

// Container duration within tolerance of the timeline plan.
export function qcDuration({ actualSeconds, expectedSeconds, toleranceSeconds = 0.5 }) {
  number(actualSeconds, 'invalid_qc_duration'); number(expectedSeconds, 'invalid_qc_duration');
  number(toleranceSeconds, 'invalid_qc_tolerance');
  const delta = Math.abs(actualSeconds - expectedSeconds);
  return check('duration', delta <= toleranceSeconds ? 'pass' : 'fail', { actualSeconds, expectedSeconds, deltaSeconds: delta });
}

// Frame dimensions match the export plan (e.g. 1920x1080 master, 1080x1920 reel).
export function qcResolution({ actualWidth, actualHeight, expectedWidth, expectedHeight }) {
  for (const [v, code] of [[actualWidth, 'invalid_qc_resolution'], [actualHeight, 'invalid_qc_resolution'],
      [expectedWidth, 'invalid_qc_resolution'], [expectedHeight, 'invalid_qc_resolution']]) number(v, code);
  const ok = actualWidth === expectedWidth && actualHeight === expectedHeight;
  return check('resolution', ok ? 'pass' : 'fail', { actual: `${actualWidth}x${actualHeight}`, expected: `${expectedWidth}x${expectedHeight}` });
}

// Audio stream presence from probe data, plus optional measured loudness.
// loudness: { inputI } from measureLoudness; min/max bounds are advisory.
export function qcAudio({ streams, requireAudio = true, loudness = null, minI = -40, maxI = 0 } = {}) {
  requireValue(Array.isArray(streams), 'invalid_qc_streams', 'qc_validation');
  const audio = streams.filter(s => s?.codec_type === 'audio');
  if (!audio.length) return check('audio', requireAudio ? 'fail' : 'na', { reason: 'no_audio_stream' });
  const details = { codec: audio[0].codec_name ?? null, channels: audio[0].channels ?? null,
    sampleRate: audio[0].sample_rate ?? null, streamCount: audio.length };
  if (loudness === null) return check('audio', 'pass', details);
  number(loudness.inputI, 'invalid_qc_loudness');
  const inRange = loudness.inputI >= minI && loudness.inputI <= maxI;
  return check('audio', inRange ? 'pass' : 'fail', { ...details, inputI: loudness.inputI, minI, maxI });
}

// Segment coverage: the planned scenes/shots tile [0, masterDurationSeconds]
// with no gaps, no overlaps and no out-of-bounds segments (within
// tolerance). Reports every gap, overlap and out-of-bounds segment
// explicitly so selective repair knows exactly what to fix. An
// out-of-bounds segment is never silently treated as valid coverage.
export function qcSegmentCoverage({ segments, masterDurationSeconds, toleranceSeconds = 0.05, name = 'segment_coverage' }) {
  requireValue(Array.isArray(segments), 'invalid_qc_segments', 'qc_validation');
  number(masterDurationSeconds, 'invalid_qc_duration');
  requireValue(masterDurationSeconds > 0, 'invalid_qc_duration', 'qc_validation');
  number(toleranceSeconds, 'invalid_qc_tolerance');
  requireValue(toleranceSeconds >= 0, 'invalid_qc_tolerance', 'qc_validation');
  const ranges = segments.map(s => {
    number(s.startSeconds, 'invalid_qc_segment'); number(s.endSeconds, 'invalid_qc_segment');
    requireValue(s.endSeconds > s.startSeconds, 'invalid_qc_segment', 'qc_validation');
    return { id: s.id ?? null, startSeconds: s.startSeconds, endSeconds: s.endSeconds };
  }).sort((a, b) => a.startSeconds - b.startSeconds);
  const outOfBounds = [];
  for (const range of ranges) {
    if (range.startSeconds < -toleranceSeconds) {
      outOfBounds.push({ id: range.id, startSeconds: range.startSeconds, endSeconds: range.endSeconds, bound: 'start' });
    } else if (range.endSeconds > masterDurationSeconds + toleranceSeconds) {
      outOfBounds.push({ id: range.id, startSeconds: range.startSeconds, endSeconds: range.endSeconds, bound: 'end' });
    }
  }
  const gaps = [], overlaps = [];
  let cursor = 0;
  for (const range of ranges) {
    if (range.startSeconds - cursor > toleranceSeconds) gaps.push({ from: cursor, to: range.startSeconds, id: range.id });
    // A segment that starts out of bounds is reported there, not double-counted as an overlap.
    else if (range.startSeconds >= -toleranceSeconds && cursor - range.startSeconds > toleranceSeconds) {
      overlaps.push({ at: range.startSeconds, id: range.id });
    }
    cursor = Math.max(cursor, range.endSeconds);
  }
  if (masterDurationSeconds - cursor > toleranceSeconds) gaps.push({ from: cursor, to: masterDurationSeconds, id: null });
  const ok = outOfBounds.length === 0 && gaps.length === 0 && overlaps.length === 0;
  return check(name, ok ? 'pass' : 'fail', { segmentCount: ranges.length, outOfBounds, gaps, overlaps });
}

// Export completeness: every planned artifact id is present with a hash and
// a non-zero size. Extra artifacts do not fail the check (drafts exist).
export function qcExportCompleteness({ expectedArtifactIds, artifacts }) {
  requireValue(Array.isArray(expectedArtifactIds) && expectedArtifactIds.length > 0, 'invalid_qc_expected', 'qc_validation');
  requireValue(Array.isArray(artifacts), 'invalid_qc_artifacts', 'qc_validation');
  const byId = new Map(artifacts.map(a => [a?.id, a]));
  const missing = [], invalid = [];
  for (const id of expectedArtifactIds) {
    const artifact = byId.get(id);
    if (!artifact) { missing.push(id); continue; }
    if (!(typeof artifact.sha256 === 'string' && /^[0-9a-f]{64}$/.test(artifact.sha256)) ||
        !(typeof artifact.byteSize === 'number' && artifact.byteSize > 0)) invalid.push(id);
  }
  const ok = missing.length === 0 && invalid.length === 0;
  return check('export_completeness', ok ? 'pass' : 'fail', { expected: expectedArtifactIds.length, missing, invalid });
}

export function summarizeQc(artifactId, checks) {
  requireValue(typeof artifactId === 'string' && artifactId.length > 0, 'invalid_qc_artifact', 'qc_validation');
  requireValue(Array.isArray(checks) && checks.length > 0, 'invalid_qc_checks', 'qc_validation');
  const failedChecks = checks.filter(c => c.status === 'fail').map(c => c.name);
  return { artifactId, status: failedChecks.length ? 'fail' : 'pass', failedChecks,
    checks, checkedAt: new Date().toISOString() };
}
