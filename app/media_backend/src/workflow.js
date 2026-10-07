import { join } from 'node:path';
import { writeFileSync } from 'node:fs';
import { createHash, randomUUID } from 'node:crypto';
import { MediaFailure, musicPrompt, songSpecInstruction } from './contracts.js';
import { routingRequirement, planSongRoute, assertSongRouteReady } from './song_routing.js';
import { initializeProvenance, recordContribution, recordLyricsVersion, recordAsset,
  assetRights, providerAssetRights, assembledRights, selectVersions, buildManifest } from './creative_provenance.js';
import { SongExecution, LeaseLost, PendingExecution, ReviewRequired } from './media_jobs.js';

export class SongWorkflow {
  constructor({ store, textProvider, musicProvider, renderer, musicCandidates, voiceCandidates = [],
    workerId = randomUUID(), leaseMs = 30000, hook }) {
    Object.assign(this, { store, textProvider, renderer, musicCandidates: musicCandidates ?? [{ provider: musicProvider }],
      voiceCandidates, workerId, leaseMs, hook });
  }
  async tick() {
    const lease = this.store.jobs.claim(this.workerId, { leaseMs: this.leaseMs });
    if (lease) await this.execute(lease);
  }
  async run(project) {
    const lease = this.store.jobs.claim(this.workerId, { projectId: project.projectId, leaseMs: this.leaseMs });
    if (lease) await this.execute(lease);
    Object.assign(project, this.store.get(project.owner, project.projectId));
  }
  async execute(lease) {
    const execution = new SongExecution(this.store, lease, { hook: this.hook });
    const project = execution.project;
    const heartbeat = setInterval(() => {
      try { this.store.jobs.renew(lease); } catch { clearInterval(heartbeat); }
    }, Math.max(10, Math.floor(this.leaseMs / 3)));
    heartbeat.unref();
    try {
      await this.advance(execution);
      project.status = 'completed'; project.failure = null;
      selectVersions(project, project.artifacts.map(a => a.id));
      project.manifest = buildManifest(project);
      this.store.jobs.terminal(lease, project, 'completed');
    } catch (error) {
      if (error?.simulatedCrash) throw error; // Test fault injection; no production caller supplies hooks.
      if (error instanceof LeaseLost) return;
      try {
        if (error instanceof PendingExecution) { this.store.jobs.release(lease, 1000); return; }
        const failure = error instanceof MediaFailure ? error : new MediaFailure('media_processing_failed', 'orchestration');
        const stage = execution.activeStage;
        const attempt = stage && this.store.jobs.attempt(stage);
        const uncertain = error instanceof ReviewRequired || attempt?.status === 'uncertain';
        // Discard unfinished assembly mutations; only completed checkpoints are canonical.
        for (const key of Object.keys(project)) delete project[key];
        Object.assign(project, this.store.getById(this.store.jobs.get(lease.jobId).project_id));
        project.failure = failure.toJSON();
        // Retry only local work, at most twice. Never replay upstream generation for a render failure.
        if (attempt?.providerId === 'local' && attempt.status !== 'completed' && attempt.localFailures < 2) {
          this.store.jobs.update(lease, stage, { status: 'prepared', localFailures: attempt.localFailures + 1, failure: failure.toJSON() });
          project.status = 'rendering'; execution.checkpoint('localRecovery', true);
          this.store.jobs.release(lease, 5000); return;
        }
        if (uncertain && stage) this.store.jobs.update(lease, stage, {
          status: 'uncertain', uncertainty: 'review_required', failure: failure.toJSON(), completedAt: this.store.jobs.timestamp(),
        });
        else if (attempt?.providerId === 'local') this.store.jobs.update(lease, stage, {
          status: 'failed', failure: failure.toJSON(), completedAt: this.store.jobs.timestamp(), localFailures: attempt.localFailures + 1,
        });
        project.status = 'failed'; project.reviewRequired = uncertain;
        this.store.jobs.terminal(lease, project, uncertain ? 'uncertain' : 'failed');
      } catch (commitError) { if (!(commitError instanceof LeaseLost)) throw commitError; }
    } finally { clearInterval(heartbeat); }
  }
  async advance(x) {
    const project = x.project;
    if (!x.done('route')) {
      await this.renderer.preflight();
      const visuals = project.artist.visualReferenceIds.map(id => this.store.visual(project.owner, id));
      if (visuals.length !== 4 || visuals.some(v => !v)) throw new MediaFailure('four_artist_visuals_required', 'preflight');
      const requirement = routingRequirement(project.language, project.preferences);
      const plan = planSongRoute(requirement, this.musicCandidates, this.voiceCandidates);
      assertSongRouteReady(plan);
      if (!project.provenance) initializeProvenance(project, {});
      const authorizationContext = (plan.voice ?? plan.music).rightsContext ?? {};
      const voiceAuthorization = plan.permissionRequired ? {
        subject: requirement.voiceIntent === 'own_voice_clone' ? 'own' : 'other', declared: requirement.voicePermissionConfirmed,
        verified: authorizationContext.voiceAuthorizationVerified === true &&
          typeof authorizationContext.voiceAuthorizationEvidenceId === 'string' && authorizationContext.voiceAuthorizationEvidenceId.trim().length > 0,
        evidenceRef: authorizationContext.voiceAuthorizationEvidenceId ?? null,
      } : null;
      project.provenance.voiceRoute = { capabilities: plan.voiceCapabilities, metadata: plan.voiceMetadata, authorization: voiceAuthorization };
      if (voiceAuthorization) recordContribution(project, { type: 'voice_direction', source: 'user',
        description: voiceAuthorization.subject === 'own' ? 'Own-voice declaration' : 'Target-voice permission declaration' });
      const textRights = providerAssetRights(this.textProvider, { generationMode: 'ai_generation' });
      project.provenance.generationRightsReview = { songSpec: textRights.verification };
      if (requirement.voiceIntent === 'reusable_identity') {
        const review = providerAssetRights(plan.music, { generationMode: 'voice_conditioned_generation',
          voiceMode: plan.permissionRequired ? 'third_party' : null, voiceAuthorization });
        project.provenance.generationRightsReview.conditionedVoice = review.verification;
        if (review.verification.status === 'blocked') throw new MediaFailure('voice_rights_incompatible', 'preflight', 409);
      }
      if (plan.voice) {
        const review = providerAssetRights(plan.voice, { generationMode: 'voice_conversion', voiceMode: requirement.voiceIntent, voiceAuthorization });
        project.provenance.generationRightsReview.voice = review.verification;
        if (review.verification.status === 'blocked') throw new MediaFailure('voice_rights_incompatible', 'preflight', 409);
      }
      x.checkpoint('route', { requirement, visuals, voiceAuthorization, textRights,
        musicIndex: this.musicCandidates.findIndex(c => c.provider === plan.music),
        voiceIndex: this.voiceCandidates.findIndex(c => c.provider === plan.voice),
        music: x.route(plan.music), text: x.route(this.textProvider), voice: plan.voice ? x.route(plan.voice) : null,
        evaluationDecision: plan.evaluationDecision, referenceAssetIds: [...project.artist.visualReferenceIds] });
    }
    const route = x.done('route'), { requirement, visuals, voiceAuthorization, textRights } = route;
    const music = this.musicCandidates[route.musicIndex]?.provider;
    const voice = this.voiceCandidates[route.voiceIndex]?.provider;
    const checkRoute = (provider, saved) => {
      if (!provider || JSON.stringify(x.route(provider)) !== JSON.stringify(saved)) throw new ReviewRequired('routing', 'provider_route_changed');
    };
    if (!x.done('specification')) {
      checkRoute(this.textProvider, route.text);
      project.status = 'specifying'; x.checkpoint('specifying');
      const spec = await x.provider('song_spec', this.textProvider, { goal: project.goal, language: project.language,
        artist: project.artist, requirement, instruction: songSpecInstruction(project.language, project.artist), rights: textRights },
      input => this.textProvider.create(input.goal, input.language, input.artist, input.requirement));
      if (requirement.userFinalLyrics !== null) spec.lyrics = requirement.userFinalLyrics;
      if (requirement.style) spec.genre = requirement.style;
      Object.assign(project, spec, { musicPrompt: musicPrompt(spec, project.artist) });
      if (requirement.userFinalLyrics === null) {
        const lyrics = recordLyricsVersion(project, spec.lyrics, 'generated', { rights: textRights });
        project.provenance.finalLyricsVersionId = lyrics.id;
      }
      for (const [type, description] of [['title', spec.title], ['structure', spec.structure], ['hook', `Suggested chorus start: ${spec.chorusStartSeconds} seconds`]]) {
        recordContribution(project, { type, source: 'generated', description });
      }
      const lyricsArtifact = await x.artifact('lyrics_publication', 'lyrics.txt', 'text/plain',
        { text: `${spec.title}\n\n${spec.lyrics}\n`, sourceArtifactIds: [], ...x.source('song_spec') },
        async (path, input) => { writeFileSync(path, input.text, { flag: 'wx', mode: 0o600 }); return {}; });
      project.artifacts.push(lyricsArtifact);
      x.linkOutput('song_spec', lyricsArtifact);
      recordAsset(project, { ...lyricsArtifact, kind: 'lyrics' }, assetRights({ ...textRights, sourceAssetIds: [project.provenance.finalLyricsVersionId] }));
      x.checkpoint('specification', spec);
    }
    const spec = x.done('specification');
    if (!x.done('audio')) {
      checkRoute(music, route.music);
      if (!x.done('audioRights')) {
        const rights = providerAssetRights(music, {
          generationMode: requirement.voiceIntent === 'reusable_identity' ? 'voice_conditioned_generation' : 'ai_generation',
          voiceMode: requirement.voiceIntent === 'reusable_identity' && route.voiceAuthorization ? 'third_party' : null,
          voiceAuthorization: voice ? null : voiceAuthorization, sourceAssetIds: [project.artifacts[0].id], userSupplied: requirement.userFinalLyrics !== null });
        project.provenance.generationRightsReview.music = rights.verification;
        project.status = 'generating'; x.checkpoint('audioRights', rights);
      }
      let audioRights = x.done('audioRights');
      let song = await x.provider('music', music, { spec, artist: project.artist, requirement,
        prompt: project.musicPrompt, rights: audioRights, sourceArtifactIds: audioRights.sourceAssetIds },
      input => music.generateSong(input.spec, input.artist, input.requirement));
      if (route.voice) {
        checkRoute(voice, route.voice);
        const vocalSource = voice.capabilities.conversionInput === 'vocal_stem' ? song.vocalSource : song;
        if (!vocalSource?.bytes?.length) throw new MediaFailure('vocal_source_unavailable', 'voice_conversion', 409);
        if (!x.done('voiceSource')) {
          const source = recordAsset(project, { id: randomUUID(), kind: 'audio', sha256: createHash('sha256').update(song.bytes).digest('hex') }, audioRights);
          const conversionSource = vocalSource === song ? source : recordAsset(project, {
            id: randomUUID(), kind: 'vocal_source', sha256: createHash('sha256').update(vocalSource.bytes).digest('hex'),
          }, assetRights({ ...audioRights, sourceAssetIds: [source.id] }));
          const profileRights = providerAssetRights(voice, { generationMode: 'voice_model', voiceMode: requirement.voiceIntent, voiceAuthorization });
          project.provenance.generationRightsReview.voiceProfile = profileRights.verification;
          x.checkpoint('voiceSource', { conversionSourceId: conversionSource.id, profileRights });
        }
        const voiceRequest = { ...requirement, artist: project.artist };
        const profile = await x.provider('voice_profile', voice, { voiceRequest }, input => voice.createVoiceProfile(input.voiceRequest));
        if (!x.done('voiceRights')) {
          const profileRecord = recordAsset(project, { id: randomUUID(), kind: 'voice_profile' }, x.done('voiceSource').profileRights);
          audioRights = providerAssetRights(voice, { generationMode: 'voice_conversion',
            sourceAssetIds: [x.done('voiceSource').conversionSourceId, profileRecord.id], voiceAuthorization,
            userSupplied: true, permissionsDeclared: requirement.voicePermissionConfirmed, voiceMode: requirement.voiceIntent });
          project.provenance.generationRightsReview.voice = audioRights.verification;
          x.checkpoint('voiceRights', audioRights);
        }
        audioRights = x.done('voiceRights');
        song = await x.provider('voice_conversion', voice, { voiceRequest, sourceStage: 'music', profile, rights: audioRights },
          input => voice.convertVoice(vocalSource, input.profile, input.voiceRequest));
      }
      const audio = await x.artifact('audio_publication', 'song.mp3', 'audio/mpeg', {
        sourceArtifactIds: audioRights.sourceAssetIds, ...x.source(route.voice ? 'voice_conversion' : 'music'),
      },
        async path => { writeFileSync(path, song.bytes, { flag: 'wx', mode: 0o600 }); return { durationSeconds: await this.renderer.validateAudio(path) }; });
      project.providerMetadata = song.metadata; project.audioArtifact = audio; project.artifacts.push(audio);
      x.linkOutput(route.voice ? 'voice_conversion' : 'music', audio);
      recordAsset(project, { ...audio, kind: 'audio' }, audioRights);
      project.status = 'rendering'; x.checkpoint('audio');
    }
    const duration = project.audioArtifact.durationSeconds;
    const hd = visuals.every(v => Math.min(v.width, v.height) >= 1080);
    for (const vertical of [false, true]) {
      const kind = vertical ? 'render_teaser' : 'render_full';
      if (x.done(kind)) continue;
      const fileName = vertical ? 'teaser.mp4' : 'youtube.mp4';
      const clipDuration = vertical ? Math.min(30, duration) : duration;
      const size = hd ? [1920, 1080] : [1280, 720];
      const input = { images: visuals.map(v => v.path), audio: join(this.store.directory(project), 'song.mp3'),
        duration: clipDuration, start: vertical ? Math.min(spec.chorusStartSeconds, duration - clipDuration) : 0,
        width: vertical ? size[1] : size[0], height: vertical ? size[0] : size[1],
        sourceArtifactIds: [project.audioArtifact.id, ...project.artist.visualReferenceIds] };
      const artifact = await x.artifact(kind, fileName, 'video/mp4', input,
        (output, saved) => this.renderer.export({ ...saved, output }),
        { role: vertical ? 'teaser' : 'full_song', aspectRatio: vertical ? '9:16' : '16:9',
          ...(vertical ? { selection: 'suggested_chorus_time_requires_listening_review' } : {}) });
      project.artifacts.push(artifact); project.videoArtifacts.push(artifact);
      recordAsset(project, { ...artifact, kind: 'video' }, assembledRights(project, input.sourceArtifactIds));
      x.checkpoint(kind);
    }
  }
}
