import test from 'node:test';
import assert from 'node:assert/strict';
import { MediaFailure } from '../src/contracts.js';
import { VoiceIntent, songPreferences, routingRequirement, planSongRoute,
  assertSongRouteReady, SingingVoiceProvider, subtitleWork, songRecoveryDecision,
  VoiceCapability, voiceCapabilityMetadata } from '../src/song_routing.js';

const provider = (id, caps = {}) => ({ providerId: id,
  capabilities: { customLyrics: true, ...caps }, supportsLanguage: l => ['my', 'en'].includes(l) });
const candidate = (id, caps) => ({ provider: provider(id, caps) });
const requirement = (preferences = {}, language = 'my') => routingRequirement(language, preferences);

test('default generated voice skips optional clone and subtitle work', () => {
  const plan = planSongRoute(requirement(), [candidate('mock-music')]);
  assert.deepEqual(plan.missing, []);
  assert.equal(plan.requirement.voiceIntent, VoiceIntent.generated);
  assert.equal(songPreferences().subtitles, 'off');
  assert.equal(plan.voice, undefined);
  assert.deepEqual(plan.stages, ['song_spec', 'song_generation', 'media_render']);
  assert.equal(subtitleWork({}, 'Final lyrics'), null);
});

test('reusable singer requires supported identity, never just vocal direction', () => {
  const r = requirement({ voiceIntent: VoiceIntent.reusableIdentity, context: 'album' });
  const unavailable = planSongRoute(r, [candidate('direction-only', { vocalDirection: true })]);
  assert.throws(() => assertSongRouteReady(unavailable), /reusable_voice_unavailable/);
  const plan = planSongRoute(r, [candidate('reusable', { reusableSingerIdentity: true, referenceVoiceUsesRealPerson: false })]);
  assert.deepEqual(plan.missing, []);
  assert.equal(plan.requirement.voiceIntent, 'reusable_identity');
  assert.equal(plan.requirement.context, 'album');
  assert.equal(plan.voice, undefined);
  assert.deepEqual(plan.voiceCapabilities, [VoiceCapability.conditioned]);
  assert.equal(plan.voiceMetadata.operations.includes(VoiceCapability.clone), false);
});

class MockVoice extends SingingVoiceProvider {
  get providerId() { return 'mock-voice'; }
  get capabilities() { return { voiceModes: ['own_voice_clone', 'custom_locked_voice'], languages: ['en', 'my'],
    voiceCapabilities: [VoiceCapability.clone, VoiceCapability.conversion], conversionInput: 'complete_song', returnsFinalMix: true }; }
}
for (const voiceIntent of ['own_voice_clone', 'custom_locked_voice']) {
  test(`${voiceIntent} requires permission and optional capable voice stage`, () => {
    const music = [candidate('music')];
    const missing = planSongRoute(requirement({ voiceIntent }), music);
    assert.deepEqual(missing.missing, ['voice_permission_required', 'singing_voice_unavailable']);
    const r = requirement({ voiceIntent, voicePermissionConfirmed: true });
    assert.throws(() => assertSongRouteReady(planSongRoute(r, music)), /singing_voice_unavailable/);
    const plan = planSongRoute(r, music, [{ provider: new MockVoice() }]);
    assert.deepEqual(plan.missing, []);
    assert.equal(plan.stages.filter(s => s === 'voice_profile').length, 1);
    assert.equal(plan.stages.filter(s => s === 'voice_conversion').length, 1);
    assert.equal(plan.voice.providerId, 'mock-voice');
  });
}

test('high likeness requires separate clone/conversion operations, never legacy or conditioned capability', () => {
  const r = requirement({ voiceIntent: 'own_voice_clone', voicePermissionConfirmed: true });
  for (const voiceCapabilities of [[], [VoiceCapability.conditioned], [VoiceCapability.clone], [VoiceCapability.conversion]]) {
    const voice = { providerId: 'incomplete', supportsVoiceMode: () => true,
      capabilities: { ...new MockVoice().capabilities, voiceCapabilities },
      async createVoiceProfile() {}, async convertVoice() {} };
    assert.ok(planSongRoute(r, [candidate('music')], [{ provider: voice }]).missing.includes('singing_voice_unavailable'));
  }
});

test('fidelity ranks before cost; quota metadata describes but never grants export entitlement', () => {
  const voice = (id, fidelity) => ({ providerId: id, supportsVoiceMode: () => true,
    capabilities: { ...new MockVoice().capabilities, identityFidelityClass: fidelity,
      billingUnit: 'export_minute', estimatedCostClass: 'higher', exportQuotaLimited: true },
    async createVoiceProfile() {}, async convertVoice() {} });
  const high = voice('high', 'high_fidelity_identity'), approx = voice('approx', 'approximate_identity');
  const plan = planSongRoute(requirement({ voiceIntent: 'own_voice_clone', voicePermissionConfirmed: true }),
    [candidate('music')], [{ provider: approx, qualityRank: 100, costRank: 1 }, { provider: high, costRank: 10 }]);
  assert.equal(plan.voice, high);
  assert.deepEqual(plan.voiceMetadata, { operations: [VoiceCapability.clone, VoiceCapability.conversion],
    billingUnit: 'export_minute', estimatedCostClass: 'higher', exportQuotaLimited: true,
    conversionRequired: true, identityFidelityClass: 'high_fidelity_identity' });
  assert.equal(voiceCapabilityMetadata(provider('unknown')).identityFidelityClass, 'unspecified');
  assert.equal(planSongRoute(requirement(), [candidate('music')], [{ provider: high }]).voice, undefined);
});

test('real-person conditioning needs permission; fictional consistency does not', () => {
  const music = [candidate('reference', { voiceCapabilities: [VoiceCapability.conditioned], referenceVoiceUsesRealPerson: true })];
  const p = { voiceIntent: 'reusable_identity' };
  assert.ok(planSongRoute(requirement(p), music).missing.includes('voice_permission_required'));
  assert.deepEqual(planSongRoute(requirement({ ...p, voicePermissionConfirmed: true }), music).missing, []);
});

test('stem-only conversion fails preflight without matching vocal source; no renderer redesign', () => {
  const voice = { supportsVoiceMode: () => true, capabilities: { ...new MockVoice().capabilities, conversionInput: 'vocal_stem' },
    async createVoiceProfile() {}, async convertVoice() {} };
  const r = requirement({ voiceIntent: 'own_voice_clone', voicePermissionConfirmed: true });
  assert.ok(planSongRoute(r, [candidate('mix-only')], [{ provider: voice }]).missing.includes('singing_voice_unavailable'));
  assert.deepEqual(planSongRoute(r, [candidate('stem-output', { vocalStemOutput: true })], [{ provider: voice }]).missing, []);
});

test('capability, language, availability and limits gate quality-first ordering', () => {
  const highQuality = { ...candidate('quality'), qualityRank: 3, costRank: 10 };
  const cheapest = { ...candidate('cheap'), qualityRank: 1, costRank: 1 };
  const off = { ...candidate('offline'), available: false, qualityRank: 100 };
  const unsupported = { provider: { ...provider('wrong-language'), supportsLanguage: () => false }, qualityRank: 100 };
  assert.equal(planSongRoute(requirement(), [cheapest, off, unsupported, highQuality]).music.providerId, 'quality');
  const r = requirement({ userFinalLyrics: 'အလင်းရောင်' });
  assert.ok(planSongRoute(r, [candidate('no-lyrics', { customLyrics: false })]).missing.length);
  assert.ok(planSongRoute(r, [candidate('limited', { maxLyricsCharacters: 2 })]).missing.length);
  assert.throws(() => routingRequirement('unsupported', {}), /invalid_request/);
  assert.throws(() => songPreferences({ voiceIntent: 'vendor-from-client' }), /invalid_request/);
});

test('requested subtitles add only an explicit alignment requirement; unavailable work fails preflight', () => {
  const plan = planSongRoute(requirement({ subtitles: 'requested' }), [candidate('music')]);
  assert.ok(plan.stages.includes('subtitle_alignment'));
  assert.throws(() => assertSongRouteReady(plan), /subtitles_unavailable/);
});

for (const lyrics of ['  မြန်မာစာသား\nနောက်တစ်ကြောင်း  ', '  Final English lyrics\nKeep this line  ']) {
  test(`canonical lyrics retained verbatim (${lyrics.includes('English') ? 'en' : 'my'}); ASR cannot replace them`, () => {
    const user = subtitleWork({ subtitles: 'requested', userFinalLyrics: lyrics, transcription: 'wrong ASR text' }, 'different generated lyrics');
    assert.equal(user.text, lyrics); assert.equal(user.source, 'user_final_lyrics');
    const generated = subtitleWork({ subtitles: 'requested', transcription: 'wrong ASR text' }, lyrics);
    assert.equal(generated.text, lyrics); assert.equal(generated.source, 'generated_final_lyrics');
    assert.equal(generated.transcription, 'alignment_or_qc_only');
  });
}

const recovery = () => ({ failure: new MediaFailure('provider_rate_limited', 'music'), approved: true,
  outcomeKnownUnbilled: true, requirement: requirement(), candidates: [candidate('old'), candidate('alternate')],
  attemptedProviderIds: ['old'] });
test('typed approved, known-unbilled failure offers at most one capable alternate; policy never invokes it', () => {
  assert.deepEqual(songRecoveryDecision(recovery()), { action: 'offer_alternate', providerId: 'alternate', maximumAdditionalAttempts: 1 });
  const options = recovery(); options.candidates.pop();
  assert.deepEqual(songRecoveryDecision(options), { action: 'offer_manual_retry', maximumAdditionalAttempts: 1 });
  assert.deepEqual(songRecoveryDecision({ ...options, candidates: [] }), { action: 'stop' });
});
test('cancellation, aesthetic rejection, unknown billing, missing approval and exhausted retry budget stop', () => {
  for (const change of [{ cancelled: true }, { aestheticRejected: true }, { approved: false },
    { outcomeKnownUnbilled: false }, { additionalAttempts: 1 }, { additionalAttempts: -1 },
    { failure: new Error('provider_rate_limited') }, { failure: new MediaFailure('provider_timeout_unknown', 'music') },
    { failure: new MediaFailure('invalid_audio_response', 'music') }]) {
    assert.deepEqual(songRecoveryDecision({ ...recovery(), ...change }), { action: 'stop' });
  }
});
