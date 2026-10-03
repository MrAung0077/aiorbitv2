import { MediaFailure, requireValue } from './contracts.js';

export const VoiceIntent = Object.freeze({
  generated: 'generated', reusableIdentity: 'reusable_identity',
  ownVoiceClone: 'own_voice_clone', customLockedVoice: 'custom_locked_voice',
});

// Persisted in the existing project JSON, not a new schema/table. Old jobs have
// the same generated-voice / no-subtitle behavior they had before this contract.
export function songPreferences(value = {}) {
  requireValue(value && typeof value === 'object' && !Array.isArray(value));
  const voiceIntent = value.voiceIntent ?? VoiceIntent.generated;
  const subtitles = value.subtitles ?? 'off';
  const context = value.context ?? 'single_song';
  const style = value.style ?? '';
  const userFinalLyrics = value.userFinalLyrics ?? null;
  const voicePermissionConfirmed = value.voicePermissionConfirmed ?? false;
  requireValue(Object.values(VoiceIntent).includes(voiceIntent));
  requireValue(['off', 'requested'].includes(subtitles));
  requireValue(['single_song', 'reusable_artist', 'album'].includes(context));
  requireValue(typeof style === 'string' && style.length <= 300);
  requireValue(userFinalLyrics === null || (typeof userFinalLyrics === 'string' && userFinalLyrics.trim().length > 0 && userFinalLyrics.length <= 10000));
  requireValue(typeof voicePermissionConfirmed === 'boolean');
  return { voiceIntent, subtitles, context, style: style.trim(), userFinalLyrics, voicePermissionConfirmed };
}

export function routingRequirement(language, preferences) {
  requireValue(['en', 'my'].includes(language));
  const p = songPreferences(preferences);
  return { capability: 'original_song', language, ...p, qualityPriority: 'quality_first' };
}

// Ranks are operator-reviewed capability metadata, never user-supplied prices
// or invented quality scores. Unknown values tie; price cannot outrank quality.
function ranked(candidates) {
  return candidates.filter(c => c.available !== false).slice().sort((a, b) =>
    (b.qualityRank ?? 0) - (a.qualityRank ?? 0) ||
    (b.reliabilityRank ?? 0) - (a.reliabilityRank ?? 0) ||
    (a.latencyRank ?? 0) - (b.latencyRank ?? 0) ||
    (a.costRank ?? 0) - (b.costRank ?? 0));
}

export function planSongRoute(requirement, candidates, voiceCandidates = []) {
  const r = routingRequirement(requirement.language, requirement);
  const requiresVoice = [VoiceIntent.ownVoiceClone, VoiceIntent.customLockedVoice].includes(r.voiceIntent);
  const music = ranked(candidates).find(c => {
    const p = c.provider, caps = p.capabilities ?? {};
    return p.supportsLanguage(r.language) &&
      (r.voiceIntent !== VoiceIntent.reusableIdentity || caps.reusableSingerIdentity === true) &&
      (r.userFinalLyrics === null || caps.customLyrics === true) &&
      (caps.maxLyricsCharacters === undefined || (r.userFinalLyrics?.length ?? 0) <= caps.maxLyricsCharacters);
  })?.provider;
  const voice = requiresVoice ? ranked(voiceCandidates).find(c =>
    c.provider.supportsVoiceMode(r.voiceIntent) &&
    c.provider.capabilities.languages.includes(r.language))?.provider : undefined;
  const missing = [];
  if (!music) missing.push(r.voiceIntent === VoiceIntent.reusableIdentity ? 'reusable_voice_unavailable' : 'song_route_unavailable');
  if (requiresVoice && !r.voicePermissionConfirmed) missing.push('voice_permission_required');
  if (requiresVoice && !voice) missing.push('singing_voice_unavailable');
  // Alignment/burn-in is deliberately not implemented in this foundation.
  if (r.subtitles === 'requested') missing.push('subtitles_unavailable');
  return { requirement: r, music, voice, missing,
    stages: ['song_spec', 'song_generation', ...(requiresVoice ? ['singing_voice'] : []),
      ...(r.subtitles === 'requested' ? ['subtitle_alignment'] : []), 'media_render'] };
}

export function assertSongRouteReady(plan) {
  if (plan.missing.length) throw new MediaFailure(plan.missing[0], 'preflight', 409);
}

export class SingingVoiceProvider {
  get providerId() { throw new Error('abstract'); }
  get capabilities() { throw new Error('abstract'); }
  supportsVoiceMode(mode) { return this.capabilities.voiceModes.includes(mode); }
  async convertOrClone(_audio, _request) { throw new Error('abstract'); }
}

// No ASR input: final lyrics stay authoritative in every language. Never trim,
// rewrite or "correct" the user's supplied lyric text here.
export function subtitleWork(preferences, generatedFinalLyrics) {
  const p = songPreferences(preferences);
  if (p.subtitles !== 'requested') return null;
  const text = p.userFinalLyrics ?? generatedFinalLyrics;
  requireValue(typeof text === 'string' && text.trim().length > 0, 'final_lyrics_required', 'preflight');
  return { text, source: p.userFinalLyrics === null ? 'generated_final_lyrics' : 'user_final_lyrics',
    timing: 'alignment_required', transcription: 'alignment_or_qc_only' };
}

// A decision only, NOT an automatic executor. Caller must have explicit spend
// approval and a known non-billable outcome before any one additional attempt.
export function songRecoveryDecision({ failure, cancelled = false, aestheticRejected = false,
  approved = false, outcomeKnownUnbilled = false, additionalAttempts = 0,
  requirement, candidates = [], attemptedProviderIds = [] } = {}) {
  if (cancelled || aestheticRejected || !approved || !outcomeKnownUnbilled ||
      !Number.isInteger(additionalAttempts) || additionalAttempts !== 0 ||
      !(failure instanceof MediaFailure) ||
      !['provider_rate_limited', 'provider_unavailable'].includes(failure.code)) return { action: 'stop' };
  const alternate = candidates.filter(c => !attemptedProviderIds.includes(c.provider.providerId));
  const plan = planSongRoute(requirement, alternate);
  if (!plan.missing.length) return { action: 'offer_alternate', providerId: plan.music.providerId, maximumAdditionalAttempts: 1 };
  if (!planSongRoute(requirement, candidates).missing.length) {
    return { action: 'offer_manual_retry', maximumAdditionalAttempts: 1 };
  }
  return { action: 'stop' };
}
