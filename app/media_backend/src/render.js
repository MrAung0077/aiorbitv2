import { spawn } from 'node:child_process';
import { MediaFailure } from './contracts.js';

export function runProcess(command, args, timeout = 15 * 60 * 1000) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { shell: false, windowsHide: true, stdio: ['ignore', 'pipe', 'ignore'] });
    let output = ''; let settled = false;
    const timer = setTimeout(() => { child.kill('SIGKILL'); fail('render_timeout'); }, timeout);
    function fail(code) { if (!settled) { settled = true; clearTimeout(timer); reject(new MediaFailure(code, 'render')); } }
    child.on('error', () => fail('ffmpeg_unavailable'));
    child.stdout.on('data', chunk => {
      output += chunk;
      if (output.length > 1024 * 1024) { child.kill('SIGKILL'); fail('invalid_media_metadata'); }
    });
    child.on('close', code => {
      if (settled) return;
      if (code !== 0) { fail('media_process_failed'); return; }
      settled = true; clearTimeout(timer); resolve(output);
    });
  });
}

export function renderArguments({ images, audio, output, duration, width, height, start = 0 }) {
  const fade = 0.6;
  const segment = (duration + fade * 3) / 4;
  const args = ['-nostdin', '-v', 'error', '-n', '-filter_complex_threads', '1'];
  for (const image of images) args.push('-loop', '1', '-framerate', '25', '-i', image);
  args.push('-i', audio);
  const filters = images.map((_, i) =>
    `[${i}:v]scale=${width}:${height}:force_original_aspect_ratio=increase,crop=${width}:${height},setsar=1,zoompan=z='min(max(zoom,pzoom)+0.00015,1.05)':d=1:s=${width}x${height}:fps=25,trim=duration=${segment.toFixed(3)},setpts=PTS-STARTPTS,format=yuv420p[v${i}]`);
  let last = 'v0';
  for (let i = 1; i < 4; i++) {
    filters.push(`[${last}][v${i}]xfade=transition=fade:duration=${fade}:offset=${((segment - fade) * i).toFixed(3)}[x${i}]`);
    last = `x${i}`;
  }
  filters.push(`[4:a]atrim=start=${start}:duration=${duration},asetpts=PTS-STARTPTS,afade=t=out:st=${Math.max(0, duration - 0.8)}:d=0.8[a]`);
  args.push('-filter_complex', filters.join(';'), '-map', `[${last}]`, '-map', '[a]', '-t', String(duration),
    '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '22', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-ar', '44100', '-ac', '2', '-movflags', '+faststart', output);
  return args;
}

export class FfmpegRenderer {
  constructor({ run = runProcess } = {}) { this.run = run; }
  async preflight() {
    await this.run('ffmpeg', ['-version'], 10000);
    await this.run('ffprobe', ['-version'], 10000);
  }
  async probe(file) {
    try {
      return JSON.parse(await this.run('ffprobe', ['-v', 'error', '-show_format', '-show_streams', '-of', 'json', file], 30000));
    } catch (error) {
      if (error instanceof MediaFailure) throw error;
      throw new MediaFailure('invalid_media_metadata', 'artifact_validation');
    }
  }
  async validateAudio(file) {
    const info = await this.probe(file);
    const stream = info.streams?.find(s => s.codec_type === 'audio');
    const duration = Number(info.format?.duration);
    if (stream?.codec_name !== 'mp3' || !Number.isFinite(duration) || duration < 45 || duration > 360) {
      throw new MediaFailure('invalid_song_audio', 'artifact_validation');
    }
    await this.run('ffmpeg', ['-nostdin', '-v', 'error', '-xerror', '-i', file, '-f', 'null', '-']);
    return duration;
  }
  async normalizeVisual(source, output) {
    const info = await this.probe(source);
    const image = info.streams?.find(s => s.codec_type === 'video');
    if (!image || image.width < 320 || image.height < 320 || image.width * image.height > 40000000) {
      throw new MediaFailure('invalid_visual', 'visual_validation', 400);
    }
    await this.run('ffmpeg', ['-nostdin', '-v', 'error', '-n', '-i', source, '-frames:v', '1', '-map_metadata', '-1', '-q:v', '2', output], 30000);
    return { width: image.width, height: image.height };
  }
  async export({ images, audio, output, duration, width, height, start = 0 }) {
    await this.run('ffmpeg', renderArguments({ images, audio, output, duration, width, height, start }));
    const info = await this.probe(output);
    const video = info.streams?.find(s => s.codec_type === 'video');
    const track = info.streams?.find(s => s.codec_type === 'audio');
    if (video?.codec_name !== 'h264' || track?.codec_name !== 'aac' || video.width !== width || video.height !== height || !Number.isFinite(Number(info.format?.duration)) || Math.abs(Number(info.format?.duration) - duration) > 0.5) {
      throw new MediaFailure('invalid_video_export', 'artifact_validation');
    }
    await this.run('ffmpeg', ['-nostdin', '-v', 'error', '-xerror', '-i', output, '-f', 'null', '-']);
    return { width, height, durationSeconds: Number(info.format.duration), startSeconds: start, videoCodec: 'h264', audioCodec: 'aac' };
  }
}
