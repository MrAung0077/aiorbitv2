import { createHash } from 'node:crypto';

const terms = 'https://suno.com/terms/';
const common = { providerId: 'suno', product: 'music_service', effectiveDate: '2026-09-03T00:00:00Z',
  verifiedAt: '2026-10-03T00:00:00Z', reviewAfter: '2026-11-02T00:00:00Z',
  sourceUrl: terms, sourceType: 'official_terms', active: true,
  copyrightStatus: 'not_determined' };
function freeze(value) {
  for (const item of Object.values(value)) if (item && typeof item === 'object') freeze(item);
  return Object.freeze(value);
}

// Dated factual summaries, not a provider integration or a copyright opinion.
// The 30-day review window is Ovexiq policy, NOT expiry of acquired rights.
export const PROVIDER_RIGHTS_RULES = freeze([
  { ...common, id: 'suno-paid-output-20260903', kind: 'commercial', plans: ['pro', 'premier'],
    generationModes: ['original_song', 'voice_model_output'], commercialUseStatus: 'conditional',
    conditions: ['subscribedAtGeneration', 'downloadedThroughApprovedChannel'], satisfiedStatus: 'allowed',
    assignmentNote: 'Provider-held output rights assigned subject to terms; no copyright assurance.',
    downloadRequirement: 'permitted_tier_download', survivesSubscriptionExpiry: true,
    verificationNotes: 'Pro/Premier and Permitted Commercial Use sections; qualified downloads retain rights after cancellation.',
    additionalSources: ['https://help.suno.com/en/articles/2425729', 'https://help.suno.com/en/articles/9601665'] },
  { ...common, id: 'suno-basic-output-20260903', kind: 'commercial', plans: ['basic', 'free'],
    generationModes: ['original_song', 'voice_model_output'], commercialUseStatus: 'nonCommercial',
    verificationNotes: 'Free or Basic Tier Accounts: personal non-commercial use.' },
  { ...common, id: 'suno-remix-20260903', kind: 'commercial', plans: ['*'], generationModes: ['remix'],
    commercialUseStatus: 'nonCommercial',
    verificationNotes: 'Remixes section. Separate-offering exceptions are not verified by this registry.' },
  { ...common, id: 'suno-own-voice-20260903', kind: 'voice', plans: ['*'],
    generationModes: ['voice_model', 'voice_model_output'], commercialUseStatus: 'conditional',
    voiceRestriction: 'own_only', verificationNotes: 'Voice Model section permits only the user\'s own voice. Model commercialization is not inferred from output permissions.' },
]);

const time = value => typeof value === 'string' ? Date.parse(value) : NaN;
const digest = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
const statuses = new Set(['allowed', 'nonCommercial', 'conditional', 'unknown', 'blocked']);
const conditionCodes = { subscribedAtGeneration: 'paid_generation_unconfirmed',
  downloadedThroughApprovedChannel: 'permitted_download_unconfirmed' };

function validRule(r) {
  return typeof r.id === 'string' && r.id.length > 0 &&
    ['commercial', 'voice'].includes(r.kind) && statuses.has(r.commercialUseStatus) &&
    Array.isArray(r.plans) && r.plans.length > 0 && Array.isArray(r.generationModes) && r.generationModes.length > 0 &&
    Number.isFinite(time(r.effectiveDate)) && Number.isFinite(time(r.verifiedAt)) &&
    time(r.reviewAfter) > time(r.verifiedAt) && typeof r.active === 'boolean' &&
    typeof r.sourceUrl === 'string' && /^https:\/\/[^\s@]+$/.test(r.sourceUrl) &&
    ['official_terms', 'official_help'].includes(r.sourceType) && typeof r.verificationNotes === 'string' && r.verificationNotes.length > 0 &&
    (r.voiceRestriction === undefined || r.voiceRestriction === 'own_only') &&
    (r.conditions === undefined || (Array.isArray(r.conditions) && r.conditions.length > 0 &&
      r.conditions.every(c => Object.hasOwn(conditionCodes, c)) && r.satisfiedStatus === 'allowed'));
}

// Plan means the verified plan AT GENERATION, not today's subscription. Inputs
// must come from trusted server/operator evidence, not an ordinary client body.
export function resolveCommercialRights(input, { rules = PROVIDER_RIGHTS_RULES, now = new Date().toISOString() } = {}) {
  const facts = { providerId: input.providerId ?? null, product: input.product ?? 'music_service',
    plan: typeof input.plan === 'string' ? input.plan.toLowerCase() : null,
    generationMode: input.generationMode ?? null, generatedAt: input.generatedAt ?? null,
    subscribedAtGeneration: input.subscribedAtGeneration === true,
    downloadedThroughApprovedChannel: input.downloadedThroughApprovedChannel === true,
    voiceMode: input.voiceMode ?? null };
  let matched = [];
  let voiceCompatible = null;
  const result = (status, reasons, primary = matched.find(r => r.kind === 'commercial') ?? matched[0]) => ({
    status, matchingRuleId: primary?.id ?? null, reasons, requiresReview: status !== 'allowed', voiceCompatible,
    evidence: { registryVersion: 1, resolvedAt: now, facts, copyrightStatus: 'not_determined',
      rules: matched.map(rule => ({ rule: structuredClone(rule), sha256: digest(rule) })) } });
  const currentTime = time(now), generatedTime = time(facts.generatedAt);
  if (!Number.isFinite(currentTime) || !Number.isFinite(generatedTime) || generatedTime > currentTime) return result('unknown', ['generation_time_unconfirmed']);
  const providerRules = rules.filter(r => r.providerId === facts.providerId && r.product === facts.product);
  if (!providerRules.length) return result('unknown', ['provider_product_unverified']);
  if (providerRules.some(r => !validRule(r))) return result('unknown', ['invalid_rights_rule']);
  const eligible = providerRules.filter(r => time(r.effectiveDate) <= generatedTime &&
    (!r.effectiveUntil || generatedTime < time(r.effectiveUntil)));
  const choose = list => {
    list.sort((a, b) => time(b.effectiveDate) - time(a.effectiveDate));
    if (list.length > 1 && list[0].effectiveDate === list[1].effectiveDate) return null;
    return list[0];
  };
  const needsVoiceCheck = ['voice_model', 'voice_model_output'].includes(facts.generationMode) ||
    ['own_voice_clone', 'custom_locked_voice', 'third_party'].includes(facts.voiceMode);
  if (needsVoiceCheck) {
    const voice = choose(eligible.filter(r => r.kind === 'voice'));
    if (!voice) return result('unknown', ['voice_rule_unverified']);
    matched.push(voice);
  }
  const commercial = choose(eligible.filter(r => r.kind === 'commercial' &&
    r.generationModes.includes(facts.generationMode) && (r.plans.includes('*') || r.plans.includes(facts.plan))));
  if (commercial) matched.push(commercial);
  if (matched.some(r => !r.active)) return result('unknown', ['rights_rule_inactive']);
  if (matched.some(r => currentTime < time(r.verifiedAt))) return result('unknown', ['verification_time_unconfirmed']);
  if (matched.some(r => currentTime >= time(r.reviewAfter))) return result('unknown', ['rights_evidence_stale']);
  if (needsVoiceCheck) {
    voiceCompatible = facts.voiceMode === 'own_voice_clone';
    if (['custom_locked_voice', 'third_party'].includes(facts.voiceMode)) return result('blocked', ['own_voice_only']);
    if (!voiceCompatible) return result('conditional', ['voice_identity_unconfirmed']);
  }
  if (!commercial) return result('unknown', [facts.generationMode === 'voice_model'
    ? 'voice_model_commercial_scope_unverified' : !facts.plan ? 'plan_unconfirmed' : 'no_compatible_rule']);
  const missing = (commercial.conditions ?? []).filter(c => facts[c] !== true).map(c => conditionCodes[c]);
  if (missing.length) return result('conditional', missing);
  return result(commercial.conditions ? commercial.satisfiedStatus : commercial.commercialUseStatus,
    [commercial.commercialUseStatus === 'nonCommercial' ? 'non_commercial_terms' : 'verified_conditions_satisfied']);
}

// Evaluate NEW publication/readiness without changing the saved generation
// snapshot. Changed, withdrawn, expired or missing evidence requires review.
export function reviewRightsVerification(verification, { rules = PROVIDER_RIGHTS_RULES, now = new Date().toISOString() } = {}) {
  const snapshots = verification?.evidence?.rules;
  if (!Array.isArray(snapshots) || !snapshots.length) return { requiresReview: true, reason: 'rights_evidence_missing' };
  for (const snapshot of snapshots) {
    const r = snapshot.rule;
    if (!r || !validRule(r) || digest(r) !== snapshot.sha256) return { requiresReview: true, reason: 'rights_evidence_invalid' };
    if (!Number.isFinite(time(now)) || time(now) < time(r.verifiedAt) || time(now) >= time(r.reviewAfter)) {
      return { requiresReview: true, reason: 'rights_evidence_stale' };
    }
    const current = rules.find(rule => rule.id === r.id);
    if (!current?.active || digest(current) !== snapshot.sha256) return { requiresReview: true, reason: 'rights_rule_changed' };
  }
  // Re-evaluate saved facts too; a snapshot alone is not proof of a qualified download.
  const fresh = resolveCommercialRights(verification.evidence.facts, { rules, now });
  const accepted = fresh.status === 'allowed' && fresh.matchingRuleId === verification.matchingRuleId &&
    fresh.evidence.rules.length === snapshots.length &&
    fresh.evidence.rules.every(s => snapshots.some(old => old.rule.id === s.rule.id && old.sha256 === s.sha256));
  return { requiresReview: !accepted, reason: accepted ? null : 'rights_conditions_unconfirmed' };
}
