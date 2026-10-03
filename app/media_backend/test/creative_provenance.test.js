import test from 'node:test';
import assert from 'node:assert/strict';
import { initializeProvenance, recordContribution, recordLyricsVersion, recordAsset, assetRights,
  assembledRights, selectVersions, approveFinal as approve, commercialReadiness as readiness, buildManifest as manifest,
  publicProvenanceSummary } from '../src/creative_provenance.js';
import { resolveCommercialRights } from '../src/provider_rights_registry.js';

const reviewOptions = { now: '2026-10-03T12:00:00Z' };
const commercialReadiness = p => readiness(p, reviewOptions);
const approveFinal = (p, ids) => approve(p, ids, reviewOptions);
const buildManifest = p => manifest(p, reviewOptions);

function project(lyrics = null) {
  const p = { projectId: 'synthetic-project', title: 'Synthetic title', goal: 'A hopeful original song',
    createdAt: '2026-10-03T00:00:00Z', status: 'completed', artifacts: [],
    artist: { visualReferenceIds: ['image'], permissionsDeclared: true },
    preferences: { voiceIntent: 'generated', subtitles: 'off', userFinalLyrics: lyrics, style: 'soft rock' } };
  initializeProvenance(p, { commercialUseRequested: true, preferences: p.preferences });
  return p;
}
const rights = (status = 'allowed', extra = {}) => assetRights({ providerId: 'suno',
  generationMode: 'original_song', commercialUseStatus: status, generatedAt: '2026-10-03T01:00:00Z',
  termsReference: 'https://suno.com/terms/', accountPlanClass: 'pro',
  verification: resolveCommercialRights({ providerId: 'suno', plan: 'pro', generationMode: 'original_song',
    generatedAt: '2026-10-03T01:00:00Z', subscribedAtGeneration: true, downloadedThroughApprovedChannel: true }, reviewOptions), ...extra });
function output(p, status = 'allowed', sourceAssetIds = []) {
  const a = { id: 'output', kind: 'audio', sha256: 'a'.repeat(64) };
  recordAsset(p, a, rights(status, { sourceAssetIds }));
  p.artifacts.push(a); selectVersions(p, [a.id]);
}

test('user lyrics, AI revision, user edit and final selection remain distinct facts', () => {
  const p = project('  User final lyrics\nOriginal line  ');
  const original = structuredClone(p.provenance.lyricVersions[0]);
  const generated = recordLyricsVersion(p, 'AI revision', 'generated', { parentVersionId: original.id, rights: rights() });
  assert.ok(p.provenance.assets.find(a => a.id === generated.id).rights.sourceAssetIds.includes(original.id));
  const edit = recordLyricsVersion(p, 'User revised the chorus', 'user', { parentVersionId: generated.id });
  selectVersions(p, [edit.id], 'user');
  assert.deepEqual(p.provenance.lyricVersions[0], original);
  assert.equal(original.text, '  User final lyrics\nOriginal line  ');
  const entries = p.provenance.contributions.filter(c => ['lyrics', 'lyric_edit'].includes(c.type));
  assert.deepEqual(entries.map(c => [c.source, c.userAuthored, c.generated]),
    [['user', true, false], ['generated', false, true], ['user', true, false]]);
  assert.ok(entries.every(c => !Number.isNaN(Date.parse(c.timestamp))));
  assert.equal(p.provenance.contributions.at(-1).type, 'selection');
  assert.equal(p.provenance.contributions.at(-1).source, 'user');
  assert.equal(buildManifest(p).finalLyricsSource.versionId, edit.id);
});

test('generated lyrics are not relabeled user-authored after approval', () => {
  const p = project();
  const generated = recordLyricsVersion(p, 'Generated final lyrics', 'generated', { rights: rights() });
  p.provenance.finalLyricsVersionId = generated.id;
  output(p, 'allowed', [generated.id]);
  approveFinal(p, ['output']);
  assert.equal(p.provenance.lyricVersions[0].source, 'generated');
  assert.equal(p.manifest.finalLyricsSource.source, 'generated');
  assert.equal(p.provenance.contributions.at(-1).type, 'final_approval');
  assert.equal(p.provenance.contributions.at(-1).userAuthored, true);
  assert.equal(p.manifest.finalSelectedVersions[0].versionId, 'output');
  assert.equal(p.manifest.finalSelectedVersions[0].sha256, 'a'.repeat(64));
  assert.equal(p.manifest.finalSelectedVersions[0].selectedBy, 'user');
});

for (const status of ['nonCommercial', 'blocked', 'unknown']) {
  test(`${status} required audio prevents commercial-ready; approval never grants rights`, () => {
    const p = project(); output(p, status); approveFinal(p, ['output']);
    assert.equal(commercialReadiness(p).status, 'COMMERCIAL_REVIEW_REQUIRED');
    assert.ok(commercialReadiness(p).reasons.some(r => r.kind === 'audio'));
    assert.equal(p.artifacts.length, 1);
    assert.equal(p.manifest.assets.find(a => a.id === 'output').rights.commercialUseStatus, status);
  });
}

test('documented allowed required assets and explicit final approval can pass', () => {
  const p = project(); output(p);
  assert.equal(commercialReadiness(p).status, 'FINAL_APPROVAL_REQUIRED');
  assert.equal(p.provenance.finalApproval.state, 'pending');
  approveFinal(p, ['output']);
  assert.equal(commercialReadiness(p).status, 'COMMERCIAL_READY');
  const count = p.provenance.contributions.length;
  approveFinal(p, ['output']); assert.equal(p.provenance.contributions.length, count);
  assert.throws(() => approveFinal(p, ['different-version']), /stale_final_selection/);
  selectVersions(p, ['output']); assert.equal(commercialReadiness(p).status, 'FINAL_APPROVAL_REQUIRED');
});

test('unknown source permissions propagate through rendered outputs; permission declaration is not a license', () => {
  const p = project();
  const image = p.provenance.assets[0];
  assert.equal(image.rights.permissionsDeclared, true);
  assert.equal(image.rights.commercialUseStatus, 'unknown');
  output(p, 'allowed', ['image']); approveFinal(p, ['output']);
  assert.equal(commercialReadiness(p).status, 'COMMERCIAL_REVIEW_REQUIRED');
  assert.equal(assembledRights(p, ['image', 'output']).commercialUseStatus, 'unknown');
  image.rights = rights('nonCommercial');
  assert.equal(assembledRights(p, ['image', 'output']).commercialUseStatus, 'nonCommercial');
});

test('permission declared for already saved images is captured without granting commercial rights', () => {
  const p = project(); p.artist.permissionsDeclared = false;
  initializeProvenance(p, { imagePermissionsDeclared: true });
  assert.equal(p.provenance.assets[0].rights.permissionsDeclared, true);
  assert.equal(p.provenance.assets[0].rights.commercialUseStatus, 'unknown');
});

test('missing records, source references, terms and incomplete jobs cannot pass', () => {
  const p = project(); output(p, 'allowed', ['missing-source']);
  assert.ok(commercialReadiness(p).reasons.some(r => r.code === 'source_rights_missing'));
  assert.equal(assetRights({ generationMode: 'ai_generation', commercialUseStatus: 'allowed' }).commercialUseStatus, 'unknown');
  p.provenance.assets = [];
  assert.equal(commercialReadiness(p).status, 'COMMERCIAL_REVIEW_REQUIRED');
  const unfinished = project(); output(unfinished); unfinished.status = 'failed';
  assert.equal(commercialReadiness(unfinished).status, 'OUTPUTS_INCOMPLETE');
  assert.throws(() => approveFinal(unfinished, ['output']), /final_output_not_ready/);
});

test('non-commercial project remains usable; unused draft does not block selected output', () => {
  const p = project(); output(p);
  recordAsset(p, { id: 'rejected-take', kind: 'audio' }, rights('nonCommercial'));
  approveFinal(p, ['output']);
  assert.equal(commercialReadiness(p).status, 'COMMERCIAL_READY');
  assert.equal(p.manifest.assets.find(a => a.id === 'rejected-take').required, false);
  p.commercialUseRequested = false;
  assert.equal(commercialReadiness(p).status, 'NOT_REQUESTED');
});

test('manifest is factual; public summary contains no internal provider/plan or copyright guarantee', () => {
  const p = project(); output(p); approveFinal(p, ['output']);
  const manifest = p.manifest;
  assert.equal(manifest.projectId, p.projectId);
  assert.equal(manifest.voiceIntent, 'generated'); assert.equal(manifest.subtitles, 'off');
  assert.equal(manifest.finalApproval.state, 'approved');
  assert.equal(manifest.assets.find(a => a.id === 'output').rights.providerId, 'suno');
  const summary = JSON.stringify(publicProvenanceSummary(p));
  assert.doesNotMatch(summary, /suno|terms\/|matchingRuleId|sourceUrl/);
  assert.doesNotMatch(summary + JSON.stringify(manifest), /copyright guaranteed|100% owned|fully copyrighted|copyright-safe/i);
  assert.throws(() => recordContribution(p, { type: 'legal_ownership', source: 'user' }), /invalid_contribution/);
});
