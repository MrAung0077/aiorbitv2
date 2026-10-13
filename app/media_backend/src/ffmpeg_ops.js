// Deterministic FFmpeg primitives for narrative / recap assembly.
//
// render.js already owns the song-specific video export (four images +
// zoompan/xfade), ffprobe parsing, audio validation and visual
// normalization — none of that is duplicated here. This module adds only
// the missing reusable operations a timeline-driven workflow needs:
// trim, concat, crop/reframe, audio normalization, subtitle burn-in
// primitives and stream muxing.
//
// Conventions shared with render.js: -nostdin -v error -n, no shell.
// Determinism extras: -map_metadata -1 strips nondeterministic container
// metadata; encode parameters are fixed. Provider-neutral: no provider
// imports, no network. Arg builders are pure (testable without ffmpeg);
// FfmpegOps executes them with an injectable runner.

import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { MediaFailure, requireValue } from './contracts.js';
import { runProcess } from './render.js';

const BASE_FLAGS = ['-nostdin', '-v', 'error', '-n'];
const VIDEO_ENCODE = ['-c:v', 'libx264', '-preset', 'veryfast', '-crf', '22', '-pix_fmt', 'yuv420p'];
const AUDIO_ENCODE = ['-c:a', 'aac', '-ar', '44100', '-ac', '2'];

function nonEmptyString(value, code) {
  requireValue(typeof value === 'string' && value.length > 0, code, 'ffmpeg_ops');
  return value;
}
function nonNegative(value, code) {
  requireValue(typeof value === 'number' && Number.isFinite(value) && value >= 0, code, 'ffmpeg_ops');
  return value;
}
function positive(value, code) {
  requireValue(typeof value === 'number' && Number.isFinite(value) && value > 0, code, 'ffmpeg_ops');
  return value;
}
function dimensions(width, height) {
  requireValue(Number.isInteger(width) && width > 0 && Number.isInteger(height) && height > 0, 'invalid_dimensions', 'ffmpeg_ops');
}

// runProcess discards stderr; loudness/volume filters report on stderr, so a
// capturing variant is a new capability, not a duplicate.
export function runProcessCapture(command, args, timeout = 15 * 60 * 1000) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { shell: false, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '', stderr = '', settled = false;
    const timer = setTimeout(() => { child.kill('SIGKILL'); fail('render_timeout'); }, timeout);
    function fail(code) { if (!settled) { settled = true; clearTimeout(timer); reject(new MediaFailure(code, 'render')); } }
    child.on('error', () => fail('ffmpeg_unavailable'));
    for (const [stream, sink] of [[child.stdout, 'stdout'], [child.stderr, 'stderr']]) {
      stream.on('data', chunk => {
        if (sink === 'stdout') stdout += chunk; else stderr += chunk;
        if (stdout.length + stderr.length > 4 * 1024 * 1024) { child.kill('SIGKILL'); fail('invalid_media_metadata'); }
      });
    }
    child.on('close', code => {
      if (settled) return;
      if (code !== 0) { fail('media_process_failed'); return; }
      settled = true; clearTimeout(timer); resolve({ stdout, stderr });
    });
  });
}

// Frame-accurate trim. -ss after -i seeks accurately (slower than
// input seeking, but a narrative cut must land on the timeline point).
// Re-encode is the default: stream copy can only cut on keyframes.
export function trimArgs({ input, startSeconds, durationSeconds, output, reencode = true }) {
  nonEmptyString(input, 'invalid_trim_input'); nonEmptyString(output, 'invalid_trim_output');
  nonNegative(startSeconds, 'invalid_trim_start'); positive(durationSeconds, 'invalid_trim_duration');
  const args = [...BASE_FLAGS, '-ss', String(startSeconds), '-i', input, '-t', String(durationSeconds), '-map_metadata', '-1'];
  if (reencode) args.push(...VIDEO_ENCODE, ...AUDIO_ENCODE, '-movflags', '+faststart');
  else args.push('-c', 'copy', '-movflags', '+faststart');
  args.push(output);
  return args;
}

// ffconcat list content. Paths are single-quote escaped per the demuxer spec.
export function concatListContent(inputs) {
  requireValue(Array.isArray(inputs) && inputs.length >= 2, 'invalid_concat_inputs', 'ffmpeg_ops');
  return inputs.map(p => `file '${nonEmptyString(p, 'invalid_concat_input').replace(/'/g, "'\\''")}'`).join('\n') + '\n';
}

export function concatArgs({ listFile, output, reencode = false }) {
  nonEmptyString(listFile, 'invalid_concat_list'); nonEmptyString(output, 'invalid_concat_output');
  const args = [...BASE_FLAGS, '-f', 'concat', '-safe', '0', '-i', listFile, '-map_metadata', '-1'];
  if (reencode) args.push(...VIDEO_ENCODE, ...AUDIO_ENCODE);
  else args.push('-c', 'copy');
  args.push('-movflags', '+faststart', output);
  return args;
}

// Reframe between aspects (e.g. 16:9 master -> 9:16 reel).
// fill: scale to cover then center-crop (no bars). fit: scale to fit then pad.
export function reframeArgs({ input, output, width, height, mode = 'fill' }) {
  nonEmptyString(input, 'invalid_reframe_input'); nonEmptyString(output, 'invalid_reframe_output');
  dimensions(width, height);
  requireValue(['fill', 'fit'].includes(mode), 'invalid_reframe_mode', 'ffmpeg_ops');
  const filter = mode === 'fill'
    ? `scale=${width}:${height}:force_original_aspect_ratio=increase,crop=${width}:${height},setsar=1,format=yuv420p`
    : `scale=${width}:${height}:force_original_aspect_ratio=decrease,pad=${width}:${height}:(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p`;
  return [...BASE_FLAGS, '-i', input, '-vf', filter, '-map_metadata', '-1', ...VIDEO_ENCODE,
    '-c:a', 'copy', '-movflags', '+faststart', output];
}

// EBU R128 normalization, single pass (deterministic for identical input).
export function normalizeAudioArgs({ input, output, targetI = -16, targetTP = -1.5, targetLRA = 11 }) {
  nonEmptyString(input, 'invalid_normalize_input'); nonEmptyString(output, 'invalid_normalize_output');
  for (const [v, code] of [[targetI, 'invalid_loudness_target'], [targetTP, 'invalid_loudness_target'], [targetLRA, 'invalid_loudness_target']]) {
    requireValue(typeof v === 'number' && Number.isFinite(v), code, 'ffmpeg_ops');
  }
  return [...BASE_FLAGS, '-i', input, '-af', `loudnorm=I=${targetI}:TP=${targetTP}:LRA=${targetLRA}`,
    '-map_metadata', '-1', ...AUDIO_ENCODE, output];
}

// Escape a file path for the subtitles video filter.
export function escapeFilterPath(path) {
  return nonEmptyString(path, 'invalid_subtitle_path').replace(/\\/g, '\\\\').replace(/:/g, '\\:').replace(/'/g, "\\'");
}

// Burn subtitles into video (re-encodes video, copies audio).
export function burnSubtitlesArgs({ input, output, subtitlesPath }) {
  nonEmptyString(input, 'invalid_burn_input'); nonEmptyString(output, 'invalid_burn_output');
  return [...BASE_FLAGS, '-i', input, '-vf', `subtitles='${escapeFilterPath(subtitlesPath)}'`,
    '-map_metadata', '-1', ...VIDEO_ENCODE, '-c:a', 'copy', '-movflags', '+faststart', output];
}

// Deterministic ASS subtitle document from caption segments
// ({ startSeconds, endSeconds, text }). PlayRes matches the target frame
// (see the ASS PlayResX/PlayResY lesson: SRT-via-ffmpeg renders huge).
export function buildAss(captions, { playResX = 1920, playResY = 1080, fontSize = 64 } = {}) {
  requireValue(Array.isArray(captions), 'invalid_ass_captions', 'ffmpeg_ops');
  dimensions(playResX, playResY);
  requireValue(Number.isInteger(fontSize) && fontSize > 0, 'invalid_ass_font_size', 'ffmpeg_ops');
  const stamp = seconds => {
    requireValue(Number.isFinite(seconds) && seconds >= 0, 'invalid_ass_timing', 'ffmpeg_ops');
    const cs = Math.round(seconds * 100);
    const h = Math.floor(cs / 360000), m = Math.floor(cs / 6000) % 60, s = Math.floor(cs / 100) % 60, c = cs % 100;
    return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}.${String(c).padStart(2, '0')}`;
  };
  const events = captions.map((cap, i) => {
    requireValue(cap && typeof cap.text === 'string' && cap.text.length > 0, 'invalid_ass_captions', 'ffmpeg_ops');
    requireValue(Number.isFinite(cap.startSeconds) && Number.isFinite(cap.endSeconds) && cap.endSeconds > cap.startSeconds,
      'invalid_ass_timing', 'ffmpeg_ops');
    const safe = cap.text.replace(/[{}\\]/g, ' ').replace(/\r?\n/g, '\\N');
    return `Dialogue: 0,${stamp(cap.startSeconds)},${stamp(cap.endSeconds)},Default,,0,0,0,,${safe}`;
  });
  return [
    '[Script Info]', 'ScriptType: v4.00+', `PlayResX: ${playResX}`, `PlayResY: ${playResY}`, 'WrapStyle: 2', 'ScaledBorderAndShadow: yes', '',
    '[V4+ Styles]', 'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding',
    `Style: Default,Arial,${fontSize},&H00FFFFFF,&H000019FF,&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,2,0,2,40,40,60,1`, '',
    '[Events]', 'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text',
    ...events, '',
  ].join('\n');
}

// Stream-copy mux of a video and an audio file into one container.
export function muxArgs({ video, audio, output, shortest = true }) {
  nonEmptyString(video, 'invalid_mux_video'); nonEmptyString(audio, 'invalid_mux_audio'); nonEmptyString(output, 'invalid_mux_output');
  const args = [...BASE_FLAGS, '-i', video, '-i', audio, '-map', '0:v:0', '-map', '1:a:0', '-c', 'copy', '-map_metadata', '-1'];
  if (shortest) args.push('-shortest');
  args.push('-movflags', '+faststart', output);
  return args;
}

// Measured loudness via loudnorm's JSON summary (stderr). Deterministic for
// identical input; used by QC audio-level checks. Note: the summary prints
// at info level, so this measurement intentionally does not use -v error.
export async function measureLoudness({ file, run = runProcessCapture }) {
  nonEmptyString(file, 'invalid_measure_input');
  const { stderr } = await run('ffmpeg', ['-nostdin', '-hide_banner', '-i', file,
    '-af', 'loudnorm=print_format=json', '-f', 'null', '-']);
  const match = stderr.match(/\{[\s\S]*"input_i"[\s\S]*\}/);
  if (!match) throw new MediaFailure('loudness_measure_failed', 'audio_qc');
  const summary = JSON.parse(match[0]);
  return { inputI: Number(summary.input_i), inputTp: Number(summary.input_tp), inputLra: Number(summary.input_lra),
    inputThreshold: Number(summary.input_thresh), targetOffset: Number(summary.target_offset) };
}

export class FfmpegOps {
  constructor({ run = runProcess } = {}) { this.run = run; }
  async trim({ input, startSeconds, durationSeconds, output, reencode = true }) {
    await this.run('ffmpeg', trimArgs({ input, startSeconds, durationSeconds, output, reencode }));
    return { output, startSeconds, durationSeconds };
  }
  async concat({ inputs, output, reencode = false }) {
    const dir = mkdtempSync(join(tmpdir(), 'ovexiq-concat-'));
    try {
      const listFile = join(dir, 'inputs.ffconcat');
      writeFileSync(listFile, concatListContent(inputs), { mode: 0o600 });
      await this.run('ffmpeg', concatArgs({ listFile, output, reencode }));
    } finally { rmSync(dir, { recursive: true, force: true }); }
    return { output, inputCount: inputs.length };
  }
  async reframe({ input, output, width, height, mode = 'fill' }) {
    await this.run('ffmpeg', reframeArgs({ input, output, width, height, mode }));
    return { output, width, height, mode };
  }
  async normalizeAudio({ input, output, targetI = -16, targetTP = -1.5, targetLRA = 11 }) {
    await this.run('ffmpeg', normalizeAudioArgs({ input, output, targetI, targetTP, targetLRA }));
    return { output, targetI, targetTP, targetLRA };
  }
  async burnSubtitles({ input, output, subtitlesPath }) {
    await this.run('ffmpeg', burnSubtitlesArgs({ input, output, subtitlesPath }));
    return { output, subtitlesPath };
  }
  async mux({ video, audio, output, shortest = true }) {
    await this.run('ffmpeg', muxArgs({ video, audio, output, shortest }));
    return { output };
  }
}
