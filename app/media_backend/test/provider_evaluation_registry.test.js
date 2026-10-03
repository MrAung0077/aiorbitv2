import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { capabilityProfile, providerEvaluation, rankEvaluatedCandidates, publicRoutingExplanation } from '../src/provider_evaluation_registry.js';
import { readProviderRegistry, recordProviderEvidence } from '../src/provider_registry_store.js';
import { planSongRoute, routingRequirement } from '../src/song_routing.js';

const now = '2026-10-03T12:00:00Z';
const profile = (providerId = 'synthetic-a', extra = {}) => ({ profileId: `${providerId}-profile`, providerId,
  capability: 'full_song_generation', supportedLanguages: ['my', 'en'], voiceCapabilities: ['GENERATED_VOICE'],
  inputTypes: ['text'], outputTypes: ['audio'], maxDuration: null, billingUnit: 'request', quotaLimited: null,
  commercialRightsRuleIds: [], apiAvailability: 'available', verifiedAt: '2026-10-03T00:00:00Z',
  evidenceSource: { type: 'operator_verified', reference: 'synthetic-fixture-only' }, active: true, ...extra });
const evaluation = (providerId = 'synthetic-a', extra = {}) => ({ evaluationId: `${providerId}-evaluation`, providerId,
  capability: 'full_song_generation', testedAt: '2026-10-03T01:00:00Z', language: 'my', style: null,
  sourceType: 'manual_test', quality: 'good', identityLikeness: 'not_applicable', pronunciation: 'good', artifacts: 'none_observed',
  latencyMs: null, workflowFriction: 'unknown', quotaCostObservation: { quotaType: null, quotaRemaining: null,
    quotaWindow: null, billingUnit: null, observedEffectiveCost: null, costEvidenceDate: null },
  sampleReferenceIds: [], operatorNotes: 'Synthetic test, not a real provider observation.', confidence: 'single_test', repeatCount: 1, active: true, ...extra });
const state = (extra = {}) => ({ availability: 'available', quotaRemaining: 3, requiredUnits: 1, billingUnit: 'request',
  validUntil: '2026-10-04T00:00:00Z', estimatedCost: 1, currency: 'USD', reliability: 'reliable', ...extra });
const candidate = (providerId = 'synthetic-a') => ({ provider: { providerId, capabilities: { customLyrics: true }, supportsLanguage: () => true } });
const request = (extra = {}) => ({ capability: 'full_song_generation', language: 'my', approvedBudget: { amount: 3, currency: 'USD' }, ...extra });
const registry = (extra = {}) => ({ now, profiles: [profile(), profile('synthetic-b')], evaluations: [evaluation(), evaluation('synthetic-b')],
  constraints: { 'synthetic-a': state(), 'synthetic-b': state() }, ...extra });
const rank = (r = request(), data = registry()) => rankEvaluatedCandidates([candidate(), candidate('synthetic-b')], r, data);

test('capability facts and observations are separate, bounded, dated and credential-free', () => {
  assert.equal(capabilityProfile(profile()).maxDuration, null);
  assert.equal(providerEvaluation(evaluation()).quality, 'good');
  assert.throws(() => capabilityProfile({ ...profile(), quality: 'excellent' }), /invalid_registry_record/);
  assert.throws(() => providerEvaluation({ ...evaluation(), quality: 8.7 }), /invalid_registry_record/);
  for (const extra of [{ apiKey: 'never-store-this' }, { operatorNotes: 'password=synthetic-secret' }, { confidence: 'repeated_observation', repeatCount: 1 }]) {
    assert.throws(() => providerEvaluation(evaluation('synthetic-a', extra)), /invalid_registry_record/);
  }
  assert.throws(() => capabilityProfile(profile('a', { evidenceSource: { type: 'operator_verified', reference: 'https://example.test/?secret=value' } })), /invalid_registry_record/);
});

test('unknown capability/language stays unknown; reusable support never grants clone', () => {
  const data = registry({ profiles: [profile('synthetic-a', { supportedLanguages: null, voiceCapabilities: null })] });
  assert.equal(rank(request(), data).selectedProviderId, null);
  const reusable = registry({ profiles: [profile('synthetic-a', { voiceCapabilities: ['VOICE_CONDITIONED_GENERATION'] })] });
  assert.equal(rank(request({ requiredVoiceCapabilities: ['TRUE_VOICE_CLONE'] }), reusable).selectedProviderId, null);
});

test('language and style-specific observations affect preference, not capabilities', () => {
  const data = registry({ evaluations: [evaluation('synthetic-a', { quality: 'poor' }), evaluation('synthetic-b'),
    evaluation('synthetic-a', { evaluationId: 'en-a', language: 'en', quality: 'excellent' }),
    evaluation('synthetic-b', { evaluationId: 'en-b', language: 'en', quality: 'poor' })] });
  assert.equal(rank(request(), data).selectedProviderId, 'synthetic-b');
  assert.equal(rank(request({ language: 'en' }), data).selectedProviderId, 'synthetic-a');
  data.evaluations.push(evaluation('synthetic-a', { evaluationId: 'rock-a', style: 'rock', quality: 'excellent', confidence: 'repeated_observation', repeatCount: 2 }));
  assert.equal(rank(request(), data).selectedProviderId, 'synthetic-b');
  assert.equal(rank(request({ style: 'rock' }), data).selectedProviderId, 'synthetic-a');
});

test('quality wins within budget, not automatically cheapest or most expensive', () => {
  const data = registry({ evaluations: [evaluation('synthetic-a', { quality: 'excellent' }), evaluation('synthetic-b', { quality: 'acceptable' })] });
  data.constraints['synthetic-a'].estimatedCost = 2;
  assert.equal(rank(request(), data).selectedProviderId, 'synthetic-a');
  data.constraints['synthetic-a'].estimatedCost = 20;
  assert.equal(rank(request(), data).selectedProviderId, 'synthetic-b');
  data.constraints['synthetic-a'].estimatedCost = 0.5;
  assert.equal(rank(request(), data).selectedProviderId, 'synthetic-a');
});

test('availability, quota exhaustion, unknown quota, stale entitlement and unknown budget fail closed', () => {
  for (const change of [{ availability: 'unavailable' }, { quotaRemaining: 0 }, { quotaRemaining: null },
    { requiredUnits: 0 }, { estimatedCost: null }, { validUntil: '2026-10-02T00:00:00Z' }, { billingUnit: 'minute' }]) {
    const data = registry(); data.constraints['synthetic-a'] = state(change);
    assert.equal(rank(request(), data).selectedProviderId, 'synthetic-b');
  }
  assert.equal(rank(request({ approvedBudget: null })).selectedProviderId, null);
  const data = registry(); data.evaluations[0].quotaCostObservation.quotaRemaining = 100;
  data.constraints['synthetic-a'].quotaRemaining = null;
  assert.equal(rank(request(), data).selectedProviderId, 'synthetic-b');
});

test('excellent quality cannot override unknown/failed rights or self-claimed rule IDs', () => {
  const data = registry(); data.profiles[0].commercialRightsRuleIds = ['suno-paid-output-20260903'];
  assert.equal(rank(request({ commercialUseRequired: true }), data).selectedProviderId, null);
  const paid = candidate('suno'); paid.provider.rightsContext = { plan: 'pro', generationMode: 'original_song',
    subscribedAtGeneration: true, downloadedThroughApprovedChannel: true };
  const verified = registry({ profiles: [profile('suno', { commercialRightsRuleIds: ['suno-paid-output-20260903'] })],
    evaluations: [evaluation('suno')], constraints: { suno: state() } });
  const choose = () => rankEvaluatedCandidates([paid], request({ commercialUseRequired: true }), verified);
  assert.equal(choose().selectedProviderId, 'suno');
  paid.provider.rightsContext.plan = 'free'; assert.equal(choose().selectedProviderId, null);
  paid.provider.rightsContext.plan = 'pro'; verified.now = '2026-11-03T00:00:00Z';
  assert.ok(choose().decisions[0].reasons.includes('commercial_rights_unconfirmed'));
});

test('single test has lower confidence than repeated matching observation without inventing precision', () => {
  const data = registry(); data.evaluations[1].confidence = 'repeated_observation'; data.evaluations[1].repeatCount = 3;
  assert.equal(rank(request(), data).selectedProviderId, 'synthetic-b');
  assert.equal(rank(request(), data).decisions[1].evidence.evaluation.confidence, 'repeated_observation');
});

test('conversion likeness evidence is independent from conditioning and requires identity permission', () => {
  const data = registry({ profiles: [profile('synthetic-a', { capability: 'singing_voice_conversion', voiceCapabilities: ['TRUE_VOICE_CLONE', 'VOICE_CONVERSION'] }),
    profile('synthetic-b', { capability: 'voice_conditioned_generation', voiceCapabilities: ['VOICE_CONDITIONED_GENERATION'] })],
  evaluations: [evaluation('synthetic-a', { capability: 'singing_voice_conversion', identityLikeness: 'strong' }),
    evaluation('synthetic-b', { capability: 'voice_conditioned_generation', identityLikeness: 'weak' })] });
  const r = request({ capability: 'singing_voice_conversion', requiredVoiceCapabilities: ['TRUE_VOICE_CLONE', 'VOICE_CONVERSION'],
    desiredIdentityFidelity: 'high_fidelity_identity', voiceMode: 'own_voice_clone' });
  assert.equal(rank(r, data).selectedProviderId, null);
  assert.equal(rank({ ...r, permissionConfirmed: true }, data).selectedProviderId, 'synthetic-a');
  assert.equal(rank({ ...r, voiceMode: 'custom_locked_voice', permissionConfirmed: true }, data).selectedProviderId, null);
  assert.equal(data.profiles[1].voiceCapabilities.includes('TRUE_VOICE_CLONE'), false);
});

test('inactive newer evidence retires prior observations; decision snapshots remain unchanged', () => {
  const data = registry(), prior = rank(request(), data), saved = JSON.stringify(prior.decisions);
  data.evaluations.push(evaluation('synthetic-a', { evaluationId: 'withdrawn', testedAt: '2026-10-03T02:00:00Z', active: false }));
  assert.equal(rank(request(), data).decisions[0].evaluationId, null);
  data.profiles.push(profile('synthetic-a', { profileId: 'retired-profile', verifiedAt: '2026-10-03T02:00:00Z', active: false }));
  assert.equal(rank(request(), data).selectedProviderId, 'synthetic-b');
  assert.equal(JSON.stringify(prior.decisions), saved);
});

test('high-fidelity task compares likeness observations between compatible conversion routes', () => {
  const data = registry();
  for (const p of data.profiles) Object.assign(p, { capability: 'singing_voice_conversion', voiceCapabilities: ['VOICE_CONVERSION'] });
  for (const e of data.evaluations) Object.assign(e, { capability: 'singing_voice_conversion', identityLikeness: 'weak' });
  data.evaluations[1].identityLikeness = 'strong';
  const r = request({ capability: 'singing_voice_conversion', desiredIdentityFidelity: 'high_fidelity_identity',
    voiceMode: 'own_voice_clone', permissionConfirmed: true });
  assert.equal(rank(r, data).selectedProviderId, 'synthetic-b');
  // Omitting the operation array must not bypass consent for a clone/conversion capability.
  assert.equal(rank({ ...r, permissionConfirmed: false }, data).selectedProviderId, null);
});

test('unknown formats/duration, manual-only API and conflicting profile dates cannot become available', () => {
  const data = registry();
  assert.equal(rank(request({ inputType: 'vocal_stem' }), data).selectedProviderId, null);
  assert.equal(rank(request({ outputType: 'midi' }), data).selectedProviderId, null);
  assert.equal(rank(request({ durationSeconds: 300 }), data).selectedProviderId, null);
  data.profiles[0].apiAvailability = 'manual_only';
  data.profiles.push(profile('synthetic-b', { profileId: 'conflicting-profile' }));
  assert.equal(rank(request(), data).selectedProviderId, null);
});

test('operator CLI records UTF-8 evidence without code changes; rejects secrets and duplicate IDs safely', t => {
  const directory = mkdtempSync(join(tmpdir(), 'ovexiq-evaluation-'));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const input = join(directory, 'input.json'), records = join(directory, 'records');
  const entry = evaluation('synthetic-a', { operatorNotes: 'မြန်မာအသံထွက် စမ်းသပ်ချက်' });
  writeFileSync(input, JSON.stringify(entry), 'utf8');
  const run = () => spawnSync(process.execPath, ['tools/provider-registry.js', records, 'evaluation', input], { encoding: 'utf8' });
  assert.equal(run().status, 0); assert.deepEqual(readProviderRegistry(records).evaluations, [entry]);
  const duplicate = run(); assert.equal(duplicate.status, 1); assert.doesNotMatch(duplicate.stderr, /မြန်မာ/);
  recordProviderEvidence(records, 'profile', profile());
  assert.equal(readProviderRegistry(records).profiles.length, 1);
  writeFileSync(input, JSON.stringify({ ...entry, operatorNotes: 'password=do-not-log' }));
  const rejected = run(); assert.equal(rejected.status, 1); assert.doesNotMatch(rejected.stderr, /do-not-log/);
  assert.equal(readProviderRegistry(records).evaluations.length, 1);
});

test('optional Song planner consumes evidence without replacing adapter, rights or subtitle gates', () => {
  const data = registry({ evaluations: [evaluation('synthetic-a', { quality: 'poor' }), evaluation('synthetic-b')] });
  const candidates = [candidate(), candidate('synthetic-b')];
  const evidence = { registry: data, musicRequest: request(), voiceRequest: request() };
  const plan = planSongRoute(routingRequirement('my', {}), candidates, [], evidence);
  assert.equal(plan.music.providerId, 'synthetic-b');
  assert.equal(plan.evaluationDecision.selectedMusicId, 'synthetic-b');
  assert.equal(plan.requirement.subtitles, 'off');
  assert.ok(planSongRoute(routingRequirement('my', { subtitles: 'requested' }), candidates, [], evidence).missing.includes('subtitles_unavailable'));
  evidence.musicRequest.commercialUseRequired = true;
  assert.equal(planSongRoute(routingRequirement('my', {}), candidates, [], evidence).music, undefined);
});

test('public explanation contains no identities/evidence and pure routing makes no network calls', () => {
  const saved = globalThis.fetch; let calls = 0;
  globalThis.fetch = () => { calls++; throw new Error('network forbidden'); };
  try {
    assert.deepEqual(publicRoutingExplanation(rank()), { status: 'compatible_route_available' });
    assert.deepEqual(publicRoutingExplanation(rank(request({ commercialUseRequired: true }))), { status: 'route_review_required' });
    assert.equal(calls, 0);
    const source = readFileSync(new URL('../src/provider_evaluation_registry.js', import.meta.url), 'utf8');
    assert.doesNotMatch(source, /BEST_PROVIDER\s*=/);
  } finally { globalThis.fetch = saved; }
});
