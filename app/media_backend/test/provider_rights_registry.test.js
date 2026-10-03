import test from 'node:test';
import assert from 'node:assert/strict';
import { PROVIDER_RIGHTS_RULES, resolveCommercialRights, reviewRightsVerification } from '../src/provider_rights_registry.js';
import { assetRights, providerAssetRights, recordAsset, commercialReadiness, publicProvenanceSummary } from '../src/creative_provenance.js';

const now = '2026-10-03T12:00:00Z';
const facts = { providerId: 'suno', plan: 'pro', generationMode: 'original_song',
  generatedAt: '2026-10-03T01:00:00Z', subscribedAtGeneration: true, downloadedThroughApprovedChannel: true };
const resolve = (change = {}, options = {}) => resolveCommercialRights({ ...facts, ...change }, { now, ...options });

for (const plan of ['pro', 'premier']) test(`${plan}: verified generation and permitted download allowed, not copyright-guaranteed`, () => {
  const result = resolve({ plan });
  assert.equal(result.status, 'allowed'); assert.equal(result.requiresReview, false);
  assert.equal(result.matchingRuleId, 'suno-paid-output-20260903');
  assert.equal(result.evidence.copyrightStatus, 'not_determined');
  assert.equal(result.evidence.rules[0].rule.sourceUrl, 'https://suno.com/terms/');
  assert.equal(result.evidence.rules[0].rule.effectiveDate, '2026-09-03T00:00:00Z');
  assert.equal(result.evidence.rules[0].rule.survivesSubscriptionExpiry, true);
  assert.equal(resolve({ plan, subscriptionActiveNow: false }).status, 'allowed');
});

for (const plan of ['free', 'basic']) test(`${plan}: download or later upgrade cannot grant commercial eligibility`, () => {
  assert.equal(resolve({ plan, currentPlan: 'premier' }).status, 'nonCommercial');
});

test('remix restriction wins over paid tier and download evidence', () => {
  for (const plan of ['pro', 'premier', 'basic', null]) {
    const result = resolve({ plan, generationMode: 'remix' });
    assert.equal(result.status, 'nonCommercial'); assert.equal(result.matchingRuleId, 'suno-remix-20260903');
  }
});

test('unconfirmed historical subscription or permitted download stays conditional', () => {
  for (const value of [undefined, false, 'true', 1]) {
    assert.equal(resolve({ downloadedThroughApprovedChannel: value }).status, 'conditional');
    assert.equal(resolve({ subscribedAtGeneration: value }).status, 'conditional');
  }
  assert.ok(resolve({ downloadedThroughApprovedChannel: false }).reasons.includes('permitted_download_unconfirmed'));
});

test('unknown plan, provider, product, generation mode and dates fail closed', () => {
  for (const change of [{ plan: null }, { plan: 'unverified-tier' }, { providerId: 'unverified-provider' },
    { product: 'different-service' }, { generationMode: 'unspecified' }, { generatedAt: null },
    { generatedAt: 'invalid' }, { generatedAt: '2026-12-01T00:00:00Z' }, { generatedAt: '2026-09-02T23:59:59Z' }]) {
    const result = resolve(change); assert.equal(result.status, 'unknown'); assert.equal(result.requiresReview, true);
  }
});

test('own voice is compatible, but model-only permission is not output commercialization', () => {
  const output = resolve({ generationMode: 'voice_model_output', voiceMode: 'own_voice_clone' });
  assert.equal(output.voiceCompatible, true); assert.equal(output.status, 'allowed');
  assert.equal(output.evidence.rules.length, 2);
  const model = resolve({ generationMode: 'voice_model', voiceMode: 'own_voice_clone' });
  assert.equal(model.voiceCompatible, true); assert.notEqual(model.status, 'allowed');
  assert.equal(model.requiresReview, true);
});

test('third-party voice is blocked even when permission is claimed; missing identity requires review', () => {
  for (const voiceMode of ['custom_locked_voice', 'third_party']) {
    assert.equal(resolve({ generationMode: 'voice_model_output', voiceMode, permissionsDeclared: true }).status, 'blocked');
  }
  assert.equal(resolve({ generationMode: 'voice_model_output', voiceMode: null }).status, 'conditional');
});

test('review window boundary, inactive rules, malformed rules and ambiguous rules fail closed', () => {
  assert.equal(resolve({}, { now: '2026-11-02T00:00:00Z' }).status, 'unknown');
  assert.ok(resolve({}, { now: '2026-11-02T00:00:00Z' }).reasons.includes('rights_evidence_stale'));
  const inactive = structuredClone(PROVIDER_RIGHTS_RULES); inactive[0].active = false;
  assert.ok(resolve({}, { rules: inactive }).reasons.includes('rights_rule_inactive'));
  const malformed = structuredClone(PROVIDER_RIGHTS_RULES); delete malformed[0].sourceUrl;
  assert.ok(resolve({}, { rules: malformed }).reasons.includes('invalid_rights_rule'));
  const unsupportedCondition = structuredClone(PROVIDER_RIGHTS_RULES); unsupportedCondition[0].conditions = ['assumeOwnership'];
  assert.equal(resolve({}, { rules: unsupportedCondition }).status, 'unknown');
  assert.equal(resolve({}, { rules: [...PROVIDER_RIGHTS_RULES, { ...PROVIDER_RIGHTS_RULES[0], id: 'conflict' }] }).status, 'unknown');
});

test('historical snapshots survive registry updates; current publication review flags changes without mutation', () => {
  const registry = structuredClone(PROVIDER_RIGHTS_RULES);
  const verification = resolve({}, { rules: registry });
  const saved = JSON.stringify(verification);
  assert.equal(reviewRightsVerification(verification, { now }).requiresReview, false);
  registry[0].active = false;
  assert.equal(reviewRightsVerification(verification, { now, rules: registry }).reason, 'rights_rule_changed');
  assert.equal(reviewRightsVerification(verification, { now: '2026-11-02T00:00:00Z' }).reason, 'rights_evidence_stale');
  assert.equal(JSON.stringify(verification), saved);
  assert.equal(PROVIDER_RIGHTS_RULES[0].active, true);
  const forged = structuredClone(verification); forged.evidence.rules[0].rule.reviewAfter = '2099-01-01T00:00:00Z';
  assert.equal(reviewRightsVerification(forged, { now }).reason, 'rights_evidence_invalid');
});

test('generated asset records rule snapshot, conditional status and fresh-time commercial guard', () => {
  const provider = { providerId: 'suno', rightsContext: facts };
  const rights = providerAssetRights(provider, { generationMode: 'original_song', generatedAt: facts.generatedAt }, { now });
  const project = { status: 'completed', commercialUseRequested: true, artifacts: [{ id: 'final' }],
    provenance: { assets: [], contributions: [], finalApproval: { state: 'approved' } } };
  recordAsset(project, { id: 'final', kind: 'audio' }, rights);
  const historical = JSON.stringify(project.provenance);
  assert.equal(rights.matchingRuleId, 'suno-paid-output-20260903');
  assert.equal(commercialReadiness(project, { now }).status, 'COMMERCIAL_READY');
  assert.equal(commercialReadiness(project, { now: '2026-11-02T00:00:00Z' }).status, 'COMMERCIAL_REVIEW_REQUIRED');
  assert.equal(JSON.stringify(project.provenance), historical);
  assert.doesNotMatch(JSON.stringify(publicProvenanceSummary(project)), /suno|providerId|sourceUrl|subscription|copyright guaranteed|100% owned/i);
  const conditional = providerAssetRights({ providerId: 'suno', rightsContext: { ...facts, downloadedThroughApprovedChannel: false } },
    { generationMode: 'original_song', generatedAt: facts.generatedAt }, { now });
  assert.equal(conditional.commercialUseStatus, 'conditional');
});

test('legacy declared allowed or copied evidence cannot bypass verified provider evidence', () => {
  const rights = assetRights({ providerId: 'unverified', generationMode: 'ai_generation', commercialUseStatus: 'allowed',
    termsReference: 'https://example.test/terms' });
  const p = { status: 'completed', commercialUseRequested: true, artifacts: [{ id: 'a' }],
    provenance: { assets: [], finalApproval: { state: 'approved' } } };
  recordAsset(p, { id: 'a', kind: 'audio' }, rights);
  assert.equal(commercialReadiness(p, { now }).status, 'COMMERCIAL_REVIEW_REQUIRED');
  p.provenance.assets[0].rights.verification = resolve();
  assert.equal(commercialReadiness(p, { now }).status, 'COMMERCIAL_REVIEW_REQUIRED');
  assert.equal(providerAssetRights({ providerId: 'unverified', commercialRights: rights },
    { generationMode: 'ai_generation', generatedAt: facts.generatedAt }, { now }).commercialUseStatus, 'unknown');
});

test('runtime resolver performs no fetch or provider call', () => {
  const original = globalThis.fetch;
  let calls = 0;
  globalThis.fetch = () => { calls++; throw new Error('network forbidden'); };
  try { resolve(); reviewRightsVerification(resolve(), { now }); } finally { globalThis.fetch = original; }
  assert.equal(calls, 0);
});
