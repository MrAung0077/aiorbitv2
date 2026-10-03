import { join } from 'node:path';
import { createHash, randomUUID } from 'node:crypto';
import { MediaFailure, musicPrompt } from './contracts.js';
import { routingRequirement, planSongRoute, assertSongRouteReady } from './song_routing.js';
import { initializeProvenance, recordContribution, recordLyricsVersion, recordAsset,
  assetRights, assembledRights, selectVersions, buildManifest } from './creative_provenance.js';

export class SongWorkflow {
  constructor({ store, textProvider, musicProvider, renderer, musicCandidates, voiceCandidates = [] }) {
    Object.assign(this, { store, textProvider, renderer, musicCandidates: musicCandidates ?? [{ provider: musicProvider }], voiceCandidates });
  }
  async run(project) {
    if (project.status !== 'queued') return; // Never replay a paid/in-flight stage.
    try {
      await this.renderer.preflight();
      const visuals = project.artist.visualReferenceIds.map(id => this.store.visual(project.owner, id));
      if (visuals.length !== 4 || visuals.some(v => !v)) throw new MediaFailure('four_artist_visuals_required', 'preflight');
      const requirement = routingRequirement(project.language, project.preferences);
      const plan = planSongRoute(requirement, this.musicCandidates, this.voiceCandidates);
      assertSongRouteReady(plan); // All missing capabilities fail before any paid stage.
      if (!project.provenance) initializeProvenance(project, {}); // Older queued jobs; do not infer historical rights.
      project.status = 'specifying'; this.store.save(project);
      const spec = await this.textProvider.create(project.goal, project.language, project.artist, requirement);
      if (requirement.userFinalLyrics !== null) spec.lyrics = requirement.userFinalLyrics;
      if (requirement.style) spec.genre = requirement.style;
      Object.assign(project, spec, { musicPrompt: musicPrompt(spec, project.artist) });
      const textRights = assetRights({ ...this.textProvider.commercialRights,
        providerId: this.textProvider.providerId ?? null, generationMode: 'ai_generation' });
      if (requirement.userFinalLyrics === null) {
        const lyrics = recordLyricsVersion(project, spec.lyrics, 'generated', { rights: textRights });
        project.provenance.finalLyricsVersionId = lyrics.id;
      }
      for (const [type, description] of [['title', spec.title], ['structure', spec.structure],
        ['hook', `Suggested chorus start: ${spec.chorusStartSeconds} seconds`]]) {
        recordContribution(project, { type, source: 'generated', description });
      }
      this.store.write(project, 'lyrics.txt', `${spec.title}\n\n${spec.lyrics}\n`);
      const lyricsArtifact = this.store.artifact(project, 'lyrics.txt', 'text/plain');
      recordAsset(project, { ...lyricsArtifact, kind: 'lyrics' }, assetRights({ ...textRights,
        sourceAssetIds: [project.provenance.finalLyricsVersionId] }));
      // Persist intent before calling the billable provider. Unknown outcomes stop,
      // rather than automatically issuing another charged request after restart.
      project.status = 'generating'; this.store.save(project);
      let song = await plan.music.generateSong(spec, project.artist, requirement);
      let audioRights = assetRights({ ...plan.music.commercialRights, providerId: plan.music.providerId ?? null,
        generationMode: 'ai_generation', sourceAssetIds: [lyricsArtifact.id],
        userSupplied: requirement.userFinalLyrics !== null });
      if (plan.voice) {
        const source = recordAsset(project, { id: randomUUID(), kind: 'audio',
          sha256: createHash('sha256').update(song.bytes).digest('hex') }, audioRights);
        this.store.save(project); // Retain generation evidence before an optional paid voice stage.
        song = await plan.voice.convertOrClone(song, { ...requirement, artist: project.artist });
        audioRights = assetRights({ ...plan.voice.commercialRights, providerId: plan.voice.providerId,
          generationMode: 'voice_conversion', sourceAssetIds: [source.id],
          userSupplied: true, permissionsDeclared: requirement.voicePermissionConfirmed });
      }
      this.store.write(project, 'song.mp3', song.bytes);
      project.providerMetadata = song.metadata;
      this.store.save(project);
      const directory = this.store.directory(project);
      const audio = join(directory, 'song.mp3');
      const duration = await this.renderer.validateAudio(audio);
      project.audioArtifact = this.store.artifact(project, 'song.mp3', 'audio/mpeg', { durationSeconds: duration });
      recordAsset(project, { ...project.audioArtifact, kind: 'audio' }, audioRights);
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
        recordAsset(project, { ...artifact, kind: 'video' }, assembledRights(project,
          [project.audioArtifact.id, ...project.artist.visualReferenceIds]));
        project.videoArtifacts.push(artifact); this.store.save(project);
      }
      project.status = 'completed';
      selectVersions(project, project.artifacts.map(a => a.id)); // Assembly selection is not user approval.
      project.manifest = buildManifest(project);
      this.store.save(project);
    } catch (error) {
      const failure = error instanceof MediaFailure ? error : new MediaFailure('media_processing_failed', 'orchestration');
      project.status = 'failed'; project.failure = failure.toJSON(); this.store.save(project);
    }
  }
}
