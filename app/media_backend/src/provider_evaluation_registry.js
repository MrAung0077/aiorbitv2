import { providerAssetRights } from './creative_provenance.js';

export const ProviderCapabilities = Object.freeze(['full_song_generation', 'lyrics_conditioned_song_generation',
  'instrumental_generation', 'generated_vocal', 'reusable_singer_identity', 'voice_conditioned_generation',
  'true_voice_clone', 'singing_voice_conversion', 'vocal_isolation', 'stem_generation', 'audio_extension', 'remix', 'cover', 'audio_edit']);
const voiceOperations = ['GENERATED_VOICE', 'VOICE_CONDITIONED_GENERATION', 'TRUE_VOICE_CLONE', 'VOICE_CONVERSION'];
const quality = ['unknown', 'poor', 'acceptable', 'good', 'excellent'];
const likeness = ['not_applicable', 'unknown', 'weak', 'moderate', 'strong'];
const pronunciation = ['unknown', 'problematic', 'mixed', 'good'];
const confidence = ['single_test', 'repeated_observation', 'well_established'];
const id = v => typeof v === 'string' && /^[a-zA-Z0-9_.:-]{1,100}$/.test(v);
const text = v => typeof v === 'string' && v.length <= 1200;
const date = v => typeof v === 'string' && Number.isFinite(Date.parse(v));
const optionalNumber = v => v === null || (Number.isFinite(v) && v >= 0);
function check(ok) { if (!ok) throw new Error('invalid_registry_record'); }
function object(v, fields) {
  check(v && typeof v === 'object' && !Array.isArray(v) && Object.keys(v).every(k => fields.includes(k)));
}
function strings(v, allowed) { return v === null || (Array.isArray(v) && v.every(s => allowed ? allowed.includes(s) : id(s))); }
function credentialFree(v) {
  // Defense in depth, not a general secret detector. Never echo rejected input.
  check(!/-----BEGIN .*PRIVATE KEY|\bsk-[\w-]{20,}|\bAIza[\w-]{25,}|\bBearer\s+\S+|(?:api[_ -]?key|password|secret|token)\s*[:=]|https?:\/\/[^\s/]*@|https?:\/\/\S*[?]/i.test(JSON.stringify(v)));
}

export function capabilityProfile(value) {
  object(value, ['profileId', 'providerId', 'capability', 'supportedLanguages', 'voiceCapabilities', 'inputTypes', 'outputTypes',
    'maxDuration', 'billingUnit', 'quotaLimited', 'commercialRightsRuleIds', 'apiAvailability', 'verifiedAt', 'evidenceSource', 'active']);
  check(id(value.profileId) && id(value.providerId) && ProviderCapabilities.includes(value.capability));
  check(strings(value.supportedLanguages) && strings(value.voiceCapabilities, voiceOperations) && strings(value.inputTypes) && strings(value.outputTypes));
  check(optionalNumber(value.maxDuration) && (value.billingUnit === null || id(value.billingUnit)) &&
    [true, false, null].includes(value.quotaLimited) && strings(value.commercialRightsRuleIds));
  check(['unknown', 'manual_only', 'available', 'unavailable'].includes(value.apiAvailability) &&
    date(value.verifiedAt) && typeof value.active === 'boolean');
  object(value.evidenceSource, ['type', 'reference']);
  check(['official_documentation', 'operator_verified', 'provider_declared'].includes(value.evidenceSource.type) &&
    text(value.evidenceSource.reference) && value.evidenceSource.reference.length > 0);
  credentialFree(value);
  return structuredClone(value);
}

export function providerEvaluation(value) {
  object(value, ['evaluationId', 'providerId', 'capability', 'testedAt', 'language', 'style', 'sourceType', 'quality',
    'identityLikeness', 'pronunciation', 'artifacts', 'latencyMs', 'workflowFriction', 'quotaCostObservation',
    'sampleReferenceIds', 'operatorNotes', 'confidence', 'repeatCount', 'active']);
  check(id(value.evaluationId) && id(value.providerId) && ProviderCapabilities.includes(value.capability) && date(value.testedAt) && id(value.language));
  check(value.style === null || text(value.style));
  check(['manual_test', 'controlled_benchmark', 'production_observation'].includes(value.sourceType));
  check(quality.includes(value.quality) && likeness.includes(value.identityLikeness) && pronunciation.includes(value.pronunciation));
  check(['unknown', 'none_observed', 'minor', 'major'].includes(value.artifacts) && optionalNumber(value.latencyMs) &&
    ['unknown', 'low', 'medium', 'high'].includes(value.workflowFriction));
  check(Array.isArray(value.sampleReferenceIds) && strings(value.sampleReferenceIds) && text(value.operatorNotes));
  check(confidence.includes(value.confidence) && Number.isSafeInteger(value.repeatCount) && value.repeatCount >= 1 &&
    (value.confidence === 'single_test' || value.repeatCount > 1) && typeof value.active === 'boolean');
  const q = value.quotaCostObservation;
  object(q, ['quotaType', 'quotaRemaining', 'quotaWindow', 'billingUnit', 'observedEffectiveCost', 'costEvidenceDate']);
  check([q.quotaType, q.quotaWindow, q.billingUnit].every(v => v === null || id(v)) && optionalNumber(q.quotaRemaining));
  if (q.observedEffectiveCost !== null) {
    object(q.observedEffectiveCost, ['amount', 'currency']);
    check(Number.isFinite(q.observedEffectiveCost.amount) && q.observedEffectiveCost.amount >= 0 &&
      /^[A-Z]{3}$/.test(q.observedEffectiveCost.currency) && date(q.costEvidenceDate));
  } else check(q.costEvidenceDate === null || date(q.costEvidenceDate));
  credentialFree(value);
  return structuredClone(value);
}

// Pure, opt-in planning boundary. All constraints come from trusted operator
// state, never from model output/client-granted spending authority. No execution,
// quota reservation, automatic refresh, global winner or real provider seeds.
export function rankEvaluatedCandidates(candidates, request, registry) {
  const now = registry.now ?? new Date().toISOString();
  const profiles = (registry.profiles ?? []).map(capabilityProfile);
  const evaluations = (registry.evaluations ?? []).map(providerEvaluation);
  const operationForCapability = { true_voice_clone: 'TRUE_VOICE_CLONE', singing_voice_conversion: 'VOICE_CONVERSION',
    reusable_singer_identity: 'VOICE_CONDITIONED_GENERATION', voice_conditioned_generation: 'VOICE_CONDITIONED_GENERATION',
    generated_vocal: 'GENERATED_VOICE' };
  const requiredOperations = [...new Set([...(request.requiredVoiceCapabilities ?? []),
    ...(operationForCapability[request.capability] ? [operationForCapability[request.capability]] : [])])];
  const eligible = [], decisions = [];
  for (const candidate of candidates) {
    const provider = candidate.provider;
    const profilesForTask = profiles.filter(p => p.providerId === provider.providerId && p.capability === request.capability &&
      Date.parse(p.verifiedAt) <= Date.parse(now)).sort((a, b) => Date.parse(b.verifiedAt) - Date.parse(a.verifiedAt));
    const p = profilesForTask[0], state = registry.constraints?.[provider.providerId];
    const reasons = [];
    if (!p?.active || (profilesForTask[1]?.verifiedAt === p?.verifiedAt) ||
        !p.supportedLanguages?.includes(request.language) ||
        !requiredOperations.every(v => p.voiceCapabilities?.includes(v)) ||
        (request.inputType != null && !p.inputTypes?.includes(request.inputType)) ||
        (request.outputType != null && !p.outputTypes?.includes(request.outputType)) ||
        (request.durationSeconds != null && (p.maxDuration === null || p.maxDuration < request.durationSeconds))) reasons.push('capability_unconfirmed');
    if (candidate.available === false || p?.apiAvailability !== 'available' || state?.availability !== 'available') reasons.push('unavailable');
    // Observed quota/cost is historical evidence, never a live entitlement.
    if (!Number.isFinite(state?.quotaRemaining) || !Number.isFinite(state?.requiredUnits) || state.requiredUnits <= 0 ||
        state.quotaRemaining < state.requiredUnits || state.billingUnit !== p?.billingUnit || !p?.billingUnit ||
        !date(state?.validUntil) || Date.parse(state.validUntil) <= Date.parse(now)) reasons.push('quota_unconfirmed_or_exhausted');
    if (!Number.isFinite(state?.estimatedCost) || state.estimatedCost < 0 ||
        !Number.isFinite(request.approvedBudget?.amount) || request.approvedBudget.amount < state.estimatedCost ||
        !/^[A-Z]{3}$/.test(state?.currency ?? '') || request.approvedBudget.currency !== state.currency) reasons.push('budget_unconfirmed_or_exceeded');
    const identity = requiredOperations.some(v => ['TRUE_VOICE_CLONE', 'VOICE_CONVERSION'].includes(v)) ||
      request.realVoiceReference === true || (requiredOperations.includes('VOICE_CONDITIONED_GENERATION') &&
        request.realVoiceReference !== false && provider.capabilities?.referenceVoiceUsesRealPerson !== false);
    if (identity && (request.permissionConfirmed !== true || (request.voiceMode !== 'own_voice_clone' &&
        !(provider.rightsContext?.voiceAuthorizationVerified === true && id(provider.rightsContext?.voiceAuthorizationEvidenceId))))) reasons.push('voice_permission_required');
    const rights = providerAssetRights(provider, { generationMode: request.generationMode ?? 'ai_generation',
      generatedAt: now, voiceMode: request.voiceMode }, { now, ...(registry.rightsRules ? { rules: registry.rightsRules } : {}) });
    if (rights.commercialUseStatus === 'blocked' || (request.commercialUseRequired === true &&
        (rights.commercialUseStatus !== 'allowed' || !p?.commercialRightsRuleIds?.includes(rights.matchingRuleId)))) reasons.push('commercial_rights_unconfirmed');
    const relevant = evaluations.filter(e => e.providerId === provider.providerId && e.capability === request.capability &&
      e.language === request.language && (e.style === null || e.style === request.style) && Date.parse(e.testedAt) <= Date.parse(now));
    const retiredThrough = Math.max(-Infinity, ...relevant.filter(e => !e.active).map(e => Date.parse(e.testedAt)));
    const matching = relevant.filter(e => e.active && Date.parse(e.testedAt) > retiredThrough);
    matching.sort((a, b) => confidence.indexOf(b.confidence) - confidence.indexOf(a.confidence) || Date.parse(b.testedAt) - Date.parse(a.testedAt));
    const e = matching[0];
    const decision = { providerId: provider.providerId, profileId: p?.profileId ?? null, evaluationId: e?.evaluationId ?? null,
      required: { capability: request.capability, language: request.language, desiredIdentityFidelity: request.desiredIdentityFidelity ?? 'unspecified',
        voiceCapabilities: requiredOperations, inputType: request.inputType ?? null, outputType: request.outputType ?? null,
        durationSeconds: request.durationSeconds ?? null,
        approvedBudget: request.approvedBudget ? { amount: request.approvedBudget.amount, currency: request.approvedBudget.currency } : null,
        commercialUseRequired: request.commercialUseRequired === true }, eligible: reasons.length === 0,
      reasons: reasons.length ? reasons : ['compatible_capability', 'available', 'quota_confirmed', 'within_approved_budget',
        ...(identity ? ['permission_confirmed'] : []), ...(request.commercialUseRequired ? ['rights_verified'] : []),
        e ? 'task_specific_observation' : 'no_matching_observation'],
      // Copies make later edits incapable of changing the retained decision.
      evidence: { profile: p ?? null, evaluation: e ?? null, constraints: state ? { quotaRemaining: state.quotaRemaining,
        requiredUnits: state.requiredUnits, billingUnit: state.billingUnit, validUntil: state.validUntil,
        quotaType: state.quotaType ?? null, quotaWindow: state.quotaWindow ?? null,
        estimatedCost: state.estimatedCost, currency: state.currency, reliability: state.reliability ?? 'unknown' } : null,
        rights: rights.verification } };
    decisions.push(structuredClone(decision));
    if (!reasons.length) eligible.push({ candidate, e, state });
  }
  eligible.sort((a, b) => {
    const keys = item => [
      ...(request.desiredIdentityFidelity === 'high_fidelity_identity' ? [likeness.indexOf(item.e?.identityLikeness ?? 'unknown')] : []),
      quality.indexOf(item.e?.quality ?? 'unknown'), pronunciation.indexOf(item.e?.pronunciation ?? 'unknown'),
      confidence.indexOf(item.e?.confidence ?? 'single_test'),
      ['unknown', 'unreliable', 'mixed', 'reliable'].indexOf(item.state.reliability ?? 'unknown'),
    ];
    const aa = keys(a), bb = keys(b);
    for (let i = 0; i < aa.length; i++) if (aa[i] !== bb[i]) return bb[i] - aa[i];
    return a.state.estimatedCost - b.state.estimatedCost;
  });
  return { candidates: eligible.map(item => item.candidate), decisions,
    selectedProviderId: eligible[0]?.candidate.provider.providerId ?? null };
}

// Deliberately no interpolation or serialized internal decision in ordinary UX.
export function publicRoutingExplanation(result) {
  return { status: result.selectedProviderId ? 'compatible_route_available' : 'route_review_required' };
}
