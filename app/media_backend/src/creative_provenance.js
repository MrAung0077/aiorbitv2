import { createHash, randomUUID } from 'node:crypto';
import { requireValue } from './contracts.js';
import { resolveCommercialRights, reviewRightsVerification } from './provider_rights_registry.js';

const contributionTypes = new Set(['concept', 'lyrics', 'lyric_edit', 'title', 'structure', 'hook',
  'arrangement_direction', 'visual_direction', 'voice_direction', 'selection', 'revision_request', 'final_approval']);
const statuses = new Set(['allowed', 'nonCommercial', 'conditional', 'unknown', 'blocked']);
const now = () => new Date().toISOString();

// These are factual records, not authorship/copyright determinations. Append
// revisions rather than changing the source attributed to an earlier version.
export function recordContribution(project, { type, source, description = '', revisionRef = null }) {
  requireValue(contributionTypes.has(type) && ['user', 'generated', 'system'].includes(source), 'invalid_contribution');
  requireValue(typeof description === 'string' && description.length <= 10000, 'invalid_contribution');
  const record = { id: randomUUID(), type, source, timestamp: now(), description, revisionRef: structuredClone(revisionRef),
    userAuthored: source === 'user', generated: source === 'generated' };
  project.provenance.contributions.push(record);
  return record;
}

// Called only with trusted adapter/operator metadata, never a client or model
// response's proposed license. No plan or commercial permission is inferred.
export function assetRights({ providerId = null, generationMode, commercialUseStatus = 'unknown',
  termsReference = null, accountPlanClass = null, sourceAssetIds = [],
  userSupplied = false, permissionsDeclared = false, generatedAt = now(), verification = null }) {
  requireValue(statuses.has(commercialUseStatus), 'invalid_rights_status');
  requireValue(Array.isArray(sourceAssetIds) && sourceAssetIds.every(id => typeof id === 'string'), 'invalid_source_assets');
  const hasTerms = typeof termsReference === 'string' && termsReference.trim().length > 0;
  return { providerId, generationMode,
    commercialUseStatus: commercialUseStatus === 'allowed' && !hasTerms ? 'unknown' : commercialUseStatus,
    termsReference, generatedAt, accountPlanClass, sourceAssetIds: [...sourceAssetIds], userSupplied, permissionsDeclared,
    matchingRuleId: verification?.matchingRuleId ?? null, verification: structuredClone(verification) };
}

// Only trusted adapter/operator context enters this boundary. Do not copy
// commercialRights declarations or license assertions from generated responses.
export function providerAssetRights(provider, { generationMode, generatedAt = now(), voiceMode = null,
  sourceAssetIds = [], userSupplied = false, permissionsDeclared = false }, reviewOptions = {}) {
  const context = provider.rightsContext ?? {};
  const verification = resolveCommercialRights({ providerId: provider.providerId ?? null,
    product: context.product, plan: context.plan, generationMode: context.generationMode ?? generationMode,
    generatedAt, subscribedAtGeneration: context.subscribedAtGeneration,
    downloadedThroughApprovedChannel: context.downloadedThroughApprovedChannel, voiceMode }, reviewOptions);
  const primary = verification.evidence.rules.find(s => s.rule.id === verification.matchingRuleId)?.rule;
  return assetRights({ providerId: provider.providerId ?? null, generationMode: verification.evidence.facts.generationMode,
    generatedAt, sourceAssetIds, userSupplied, permissionsDeclared, accountPlanClass: verification.evidence.facts.plan,
    commercialUseStatus: verification.status, termsReference: primary?.sourceUrl ?? null, verification });
}

export function recordAsset(project, asset, rights) {
  requireValue(!project.provenance.assets.some(a => a.id === asset.id), 'duplicate_provenance_asset');
  const entry = { id: asset.id, kind: asset.kind, versionId: asset.versionId ?? asset.id,
    sha256: asset.sha256 ?? null, required: true, rights: structuredClone(rights) };
  project.provenance.assets.push(entry);
  return entry;
}

export function assembledRights(project, sourceAssetIds) {
  const sources = sourceAssetIds.map(id => project.provenance.assets.find(a => a.id === id));
  const states = sources.map(a => a?.rights.commercialUseStatus ?? 'unknown');
  const commercialUseStatus = ['blocked', 'nonCommercial', 'unknown', 'conditional'].find(s => states.includes(s)) ?? 'allowed';
  return assetRights({ generationMode: 'local_assembly', commercialUseStatus,
    termsReference: 'derived:source-asset-records', sourceAssetIds,
    userSupplied: sources.some(a => a?.rights.userSupplied),
    permissionsDeclared: sources.filter(a => a?.rights.userSupplied).every(a => a.rights.permissionsDeclared) });
}

export function recordLyricsVersion(project, text, source, { parentVersionId = null, rights } = {}) {
  requireValue(typeof text === 'string' && text.trim().length > 0 && text.length <= 10000, 'invalid_lyrics_version');
  requireValue(['user', 'generated'].includes(source), 'invalid_lyrics_source');
  if (parentVersionId) requireValue(project.provenance.lyricVersions.some(v => v.id === parentVersionId), 'unknown_lyrics_version');
  const version = { id: randomUUID(), text, source, parentVersionId, timestamp: now(),
    sha256: createHash('sha256').update(text, 'utf8').digest('hex') };
  project.provenance.lyricVersions.push(version);
  recordContribution(project, { type: parentVersionId ? 'lyric_edit' : 'lyrics', source, revisionRef: version.id });
  const versionRights = rights ?? assetRights({
    generationMode: source === 'user' ? 'user_input' : 'ai_generation', userSupplied: source === 'user',
    generatedAt: source === 'user' ? null : version.timestamp,
  });
  recordAsset(project, { ...version, kind: 'lyrics' }, assetRights({ ...versionRights,
    sourceAssetIds: [...new Set([...versionRights.sourceAssetIds, ...(parentVersionId ? [parentVersionId] : [])])] }));
  return version;
}

export function initializeProvenance(project, input) {
  const preferences = project.preferences ?? {};
  project.commercialUseRequested = input.commercialUseRequested ?? false;
  requireValue(typeof project.commercialUseRequested === 'boolean');
  project.provenance = { version: 1, contributions: [], lyricVersions: [], assets: [],
    selectedVersions: [], finalApproval: { state: 'pending', timestamp: null } };
  recordContribution(project, { type: 'concept', source: 'user', description: project.goal });
  if (preferences.style) recordContribution(project, {
    type: 'arrangement_direction', source: 'user', description: preferences.style });
  if (input.preferences?.voiceIntent) recordContribution(project, {
    type: 'voice_direction', source: 'user', description: preferences.voiceIntent });
  recordContribution(project, { type: 'visual_direction', source: 'user',
    description: 'User-selected artist images', revisionRef: [...project.artist.visualReferenceIds] });
  for (const id of project.artist.visualReferenceIds) recordAsset(project, { id, kind: 'image' }, assetRights({
    generationMode: 'user_input', userSupplied: true, generatedAt: null,
    permissionsDeclared: input.imagePermissionsDeclared === true || project.artist.permissionsDeclared === true }));
  if (preferences.userFinalLyrics != null) {
    const version = recordLyricsVersion(project, preferences.userFinalLyrics, 'user');
    project.provenance.finalLyricsVersionId = version.id;
  }
}

export function selectVersions(project, ids, source = 'system') {
  requireValue(Array.isArray(ids) && ids.length > 0 && new Set(ids).size === ids.length, 'invalid_selection');
  requireValue(ids.every(id => project.provenance.assets.some(a => a.id === id)), 'unknown_asset');
  const selectedLyrics = project.provenance.lyricVersions.filter(v => ids.includes(v.id));
  requireValue(selectedLyrics.length <= 1, 'ambiguous_lyrics_selection');
  if (selectedLyrics.length) project.provenance.finalLyricsVersionId = selectedLyrics[0].id;
  const selection = recordContribution(project, { type: 'selection', source, revisionRef: [...ids] });
  project.provenance.selectedVersions = ids.map(id => {
    const asset = project.provenance.assets.find(a => a.id === id);
    return { assetId: id, versionId: asset.versionId, sha256: asset.sha256, selectedBy: source, selectionId: selection.id };
  });
  // A changed take/version must be explicitly approved again.
  project.provenance.finalApproval = { state: 'pending', timestamp: null };
}

function requiredAssetIds(project) {
  const ids = new Set(project.artifacts.map(a => a.id));
  const assets = project.provenance?.assets ?? [];
  // Follow actual output dependencies, not unrelated/rejected draft takes.
  for (const id of ids) {
    for (const source of assets.find(a => a.id === id)?.rights.sourceAssetIds ?? []) ids.add(source);
  }
  return ids;
}

export function commercialReadiness(project, reviewOptions = {}) {
  if (!project.commercialUseRequested) return { status: 'NOT_REQUESTED', reasons: [] };
  const reasons = [];
  const assets = project.provenance?.assets ?? [];
  const required = requiredAssetIds(project);
  for (const a of assets.filter(a => required.has(a.id))) {
    if (a.rights.commercialUseStatus !== 'allowed') reasons.push({ assetId: a.id, kind: a.kind,
      code: a.rights.commercialUseStatus === 'unknown' ? 'rights_unconfirmed' : a.rights.commercialUseStatus });
    if (a.rights.providerId && a.rights.commercialUseStatus === 'allowed' &&
        (a.rights.verification?.evidence?.facts?.providerId !== a.rights.providerId ||
         a.rights.verification?.evidence?.facts?.generatedAt !== a.rights.generatedAt ||
         reviewRightsVerification(a.rights.verification, reviewOptions).requiresReview)) {
      reasons.push({ assetId: a.id, kind: a.kind, code: 'rights_confirmation_required' });
    }
    for (const id of a.rights.sourceAssetIds) {
      if (!assets.some(source => source.id === id)) reasons.push({ assetId: a.id, kind: a.kind, code: 'source_rights_missing' });
    }
  }
  // Missing/legacy metadata must never turn into a green commercial badge.
  if (!project.artifacts.length || !assets.length || project.artifacts.some(a => !assets.some(entry => entry.id === a.id))) {
    reasons.push({ kind: 'asset', code: 'rights_unconfirmed' });
  }
  if (reasons.length) return { status: 'COMMERCIAL_REVIEW_REQUIRED', reasons };
  if (project.status !== 'completed') return { status: 'OUTPUTS_INCOMPLETE', reasons: [] };
  if (project.provenance.finalApproval.state !== 'approved') return { status: 'FINAL_APPROVAL_REQUIRED', reasons: [] };
  return { status: 'COMMERCIAL_READY', reasons: [] };
}

export function buildManifest(project, reviewOptions = {}) {
  const p = project.provenance;
  const required = requiredAssetIds(project);
  const finalLyrics = p.lyricVersions.find(v => v.id === p.finalLyricsVersionId);
  return { version: 1, projectId: project.projectId, title: project.title, createdAt: project.createdAt,
    finalLyricsSource: finalLyrics ? { source: finalLyrics.source, versionId: finalLyrics.id, sha256: finalLyrics.sha256 } : null,
    contributionSummary: { userRecorded: p.contributions.filter(c => c.userAuthored).length,
      generatedRecorded: p.contributions.filter(c => c.generated).length,
      productionMode: p.contributions.some(c => c.userAuthored &&
        ['lyrics', 'lyric_edit', 'arrangement_direction', 'revision_request', 'title', 'structure', 'hook'].includes(c.type))
        ? 'human_direction_recorded' : 'generated_with_user_request',
      // Do not quantify "meaningful" human authorship or legal copyrightability.
      types: [...new Set(p.contributions.map(c => c.type))] },
    contributions: structuredClone(p.contributions), assets: p.assets.map(a => ({ ...structuredClone(a), required: required.has(a.id) })),
    finalSelectedVersions: structuredClone(p.selectedVersions),
    voiceIntent: project.preferences?.voiceIntent ?? 'generated', subtitles: project.preferences?.subtitles ?? 'off',
    finalApproval: structuredClone(p.finalApproval), commercialReadiness: commercialReadiness(project, reviewOptions) };
}

export function approveFinal(project, ids, reviewOptions = {}) {
  requireValue(project.status === 'completed' && project.provenance, 'final_output_not_ready');
  const expected = project.artifacts.map(a => a.id);
  requireValue(Array.isArray(ids) && ids.length === expected.length && new Set(ids).size === expected.length &&
    expected.every(id => ids.includes(id)), 'stale_final_selection');
  if (project.provenance.finalApproval.state === 'approved' &&
      project.provenance.selectedVersions.length === ids.length &&
      project.provenance.selectedVersions.every(v => ids.includes(v.assetId))) return; // Idempotent acknowledgement.
  selectVersions(project, ids, 'user');
  const approval = recordContribution(project, { type: 'final_approval', source: 'user', revisionRef: [...ids] });
  project.provenance.finalApproval = { state: 'approved', timestamp: approval.timestamp, contributionId: approval.id };
  project.manifest = buildManifest(project, reviewOptions);
}

// Deliberately omit adapter identities, terms/account detail and raw creative
// notes from the ordinary client response. Manifest stays internal to storage.
export function publicProvenanceSummary(project) {
  if (!project.provenance) return null;
  return { available: true, commercialUseRequested: project.commercialUseRequested,
    readiness: commercialReadiness(project), finalApproval: project.provenance.finalApproval.state,
    contributionCount: project.provenance.contributions.length };
}
