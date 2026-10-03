import { MediaFailure, requireValue } from './contracts.js';

export const VoiceIntent = Object.freeze({
  generated: 'generated', reusableIdentity: 'reusable_identity',
  ownVoiceClone: 'own_voice_clone', customLockedVoice: 'custom_locked_voice',
});

// Capabilities describe operations, not user intent or a likeness guarantee.
export const VoiceCapability = Object.freeze({
  generated: 'GENERATED_VOICE', conditioned: 'VOICE_CONDITIONED_GENERATION',
  clone: 'TRUE_VOICE_CLONE', conversion: 'VOICE_CONVERSION',
});
const fidelityOrder = ['unspecified', 'character_consistency', 'approximate_identity', 'high_fidelity_identity'];
export function voiceCapabilityMetadata(provider) {
  const c = provider.capabilities ?? {};
  const operations = (c.voiceCapabilities ?? []).filter(v => Object.values(VoiceCapability).includes(v));
  // Legacy reusable singer support means conditioning only, NEVER cloning.
  if (c.reusableSingerIdentity === true && !operations.includes(VoiceCapability.conditioned)) operations.push(VoiceCapability.conditioned);
  return { operations, billingUnit: c.billingUnit ?? 'unspecified', estimatedCostClass: c.estimatedCostClass ?? 'unspecified',
    exportQuotaLimited: c.exportQuotaLimited === true, conversionRequired: operations.includes(VoiceCapability.conversion),
    identityFidelityClass: fidelityOrder.includes(c.identityFidelityClass) ? c.identityFidelityClass : 'unspecified' };
}

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
      (r.voiceIntent !== VoiceIntent.reusableIdentity || voiceCapabilityMetadata(p).operations.includes(VoiceCapability.conditioned)) &&
      (r.userFinalLyrics === null || caps.customLyrics === true) &&
      (caps.maxLyricsCharacters === undefined || (r.userFinalLyrics?.length ?? 0) <= caps.maxLyricsCharacters);
  })?.provider;
  const voices = requiresVoice ? ranked(voiceCandidates).filter(c => {
    const p = c.provider, caps = p.capabilities ?? {}, ops = voiceCapabilityMetadata(p).operations;
    return ops.includes(VoiceCapability.clone) && ops.includes(VoiceCapability.conversion) &&
      typeof p.createVoiceProfile === 'function' && typeof p.convertVoice === 'function' &&
      p.supportsVoiceMode(r.voiceIntent) && caps.languages?.includes(r.language) &&
      caps.returnsFinalMix === true && (caps.conversionInput === 'complete_song' ||
        (caps.conversionInput === 'vocal_stem' && music?.capabilities?.vocalStemOutput === true));
  }).sort((a, b) => fidelityOrder.indexOf(voiceCapabilityMetadata(b.provider).identityFidelityClass) -
    fidelityOrder.indexOf(voiceCapabilityMetadata(a.provider).identityFidelityClass)) : [];
  const voice = requiresVoice ? voices[0]?.provider : undefined;
  const conditioned = r.voiceIntent === VoiceIntent.reusableIdentity;
  const permissionRequired = requiresVoice || (conditioned && music?.capabilities?.referenceVoiceUsesRealPerson !== false);
  const missing = [];
  if (!music) missing.push(r.voiceIntent === VoiceIntent.reusableIdentity ? 'reusable_voice_unavailable' : 'song_route_unavailable');
  if (permissionRequired && !r.voicePermissionConfirmed) missing.push('voice_permission_required');
  if (requiresVoice && !voice) missing.push('singing_voice_unavailable');
  // Alignment/burn-in is deliberately not implemented in this foundation.
  if (r.subtitles === 'requested') missing.push('subtitles_unavailable');
  return { requirement: r, music, voice, missing, permissionRequired,
    voiceMetadata: voiceCapabilityMetadata(voice ?? music ?? {}),
    voiceCapabilities: requiresVoice ? [VoiceCapability.clone, VoiceCapability.conversion] :
      [conditioned ? VoiceCapability.conditioned : VoiceCapability.generated],
    stages: ['song_spec', 'song_generation', ...(requiresVoice ? ['voice_profile', 'voice_conversion'] : []),
      ...(r.subtitles === 'requested' ? ['subtitle_alignment'] : []), 'media_render'] };
}

export function assertSongRouteReady(plan) {
  if (plan.missing.length) throw new MediaFailure(plan.missing[0], 'preflight', 409);
}

export class SingingVoiceProvider {
  get providerId() { throw new Error('abstract'); }
  get capabilities() { throw new Error('abstract'); }
  supportsVoiceMode(mode) { return this.capabilities.voiceModes.includes(mode); }
  async createVoiceProfile(_request) { throw new Error('abstract'); }
  // Consumes existing audio/stem and a separately created authorized profile;
  // adapter owns any required stem isolation/mixing and returns final song audio.
  async convertVoice(_audio, _profile, _request) { throw new Error('abstract'); }
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
