import { join } from 'node:path';
import { MediaFailure, musicPrompt } from './contracts.js';

export class SongWorkflow {
  constructor({ store, textProvider, musicProvider, renderer }) { Object.assign(this, { store, textProvider, musicProvider, renderer }); }
  async run(project) {
    if (project.status !== 'queued') return; // Never replay a paid/in-flight stage.
    try {
      await this.renderer.preflight();
      const visuals = project.artist.visualReferenceIds.map(id => this.store.visual(project.owner, id));
      if (visuals.length !== 4 || visuals.some(v => !v)) throw new MediaFailure('four_artist_visuals_required', 'preflight');
      if (!this.musicProvider.supportsLanguage(project.language)) throw new MediaFailure('unsupported_language', 'preflight');
      project.status = 'specifying'; this.store.save(project);
      const spec = await this.textProvider.create(project.goal, project.language, project.artist);
      Object.assign(project, spec, { musicPrompt: musicPrompt(spec, project.artist) });
      this.store.write(project, 'lyrics.txt', `${spec.title}\n\n${spec.lyrics}\n`);
      this.store.artifact(project, 'lyrics.txt', 'text/plain');
      // Persist intent before calling the billable provider. Unknown outcomes stop,
      // rather than automatically issuing another charged request after restart.
      project.status = 'generating'; this.store.save(project);
      const song = await this.musicProvider.generateSong(spec, project.artist);
      this.store.write(project, 'song.mp3', song.bytes);
      project.providerMetadata = song.metadata;
      this.store.save(project);
      const directory = this.store.directory(project);
      const audio = join(directory, 'song.mp3');
      const duration = await this.renderer.validateAudio(audio);
      project.audioArtifact = this.store.artifact(project, 'song.mp3', 'audio/mpeg', { durationSeconds: duration });
      project.status = 'rendering'; this.store.save(project);
      const hd = visuals.every(v => Math.min(v.width, v.height) >= 1080);
      const images = visuals.map(v => v.path);
      for (const vertical of [false, true]) {
        const fileName = vertical ? 'teaser.mp4' : 'youtube.mp4';
        const clipDuration = vertical ? Math.min(30, duration) : duration;
        const start = vertical ? Math.min(spec.chorusStartSeconds, duration - clipDuration) : 0;
        const size = hd ? [1920, 1080] : [1280, 720];
        const details = await this.renderer.export({ images, audio, output: join(directory, fileName), duration: clipDuration,
          start, width: vertical ? size[1] : size[0], height: vertical ? size[0] : size[1] });
        const artifact = this.store.artifact(project, fileName, 'video/mp4', {
          ...details, role: vertical ? 'teaser' : 'full_song', aspectRatio: vertical ? '9:16' : '16:9',
          ...(vertical ? { selection: 'suggested_chorus_time_requires_listening_review' } : {}),
        });
        project.videoArtifacts.push(artifact); this.store.save(project);
      }
      project.status = 'completed'; this.store.save(project);
    } catch (error) {
      const failure = error instanceof MediaFailure ? error : new MediaFailure('media_processing_failed', 'orchestration');
      project.status = 'failed'; project.failure = failure.toJSON(); this.store.save(project);
    }
  }
}
