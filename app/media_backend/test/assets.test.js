// Pure registry tests: no network, no ffmpeg, no provider calls.
import test from 'node:test';
import assert from 'node:assert/strict';
import { AssetRegistry, createAsset, ASSET_KINDS } from '../src/assets.js';
import { shot } from '../src/timeline.js';
import { MediaFailure } from '../src/contracts.js';

const fails = (fn, code) => assert.throws(fn, error => error instanceof MediaFailure && error.code === code);

test('asset kinds, labels and explicit versions are validated', () => {
  fails(() => createAsset({ kind: 'spaceship', label: 'x', version: 'v1' }), 'invalid_asset_kind');
  fails(() => createAsset({ kind: 'person', label: '  ', version: 'v1' }), 'invalid_asset_label');
  fails(() => createAsset({ kind: 'person', label: 'Rex', version: '' }), 'invalid_asset_version');
  fails(() => createAsset({ kind: 'person', label: 'Rex', version: 'v1', payload: [1, 2] }), 'invalid_asset_payload');
  const person = createAsset({ kind: 'person', label: 'Rex Aung', version: 'v1',
    payload: { descriptors: ['long black hair', 'beanie', 'denim jacket'] } });
  assert.ok(ASSET_KINDS.includes(person.kind));
  assert.equal(person.version, 'v1');
  assert.equal(person.supersedes, null);
});

test('shots reference asset ids instead of repeating descriptions', () => {
  const registry = new AssetRegistry();
  const person = registry.register(createAsset({ id: 'person-v1', kind: 'person', label: 'Rex Aung', version: 'v1' }));
  const wardrobe = registry.register(createAsset({ id: 'wardrobe-v1', kind: 'wardrobe', label: 'Stage denim', version: 'v1' }));
  const location = registry.register(createAsset({ id: 'location-v1', kind: 'location', label: 'Tea shop', version: 'v1' }));
  const take = shot({ sceneId: 's1', index: 0, startSeconds: 0, endSeconds: 10, assetIds: ['person-v1', 'wardrobe-v1', 'location-v1'] });
  const resolved = registry.resolveAll(take.assetIds);
  assert.deepEqual(resolved.map(a => a.id), ['person-v1', 'wardrobe-v1', 'location-v1']);
  assert.equal(resolved[0].label, 'Rex Aung');
  assert.ok([person, wardrobe, location].every(a => a.id));
  // A shot pointing at a missing asset fails loudly, never silently.
  fails(() => registry.resolveAll(['person-v1', 'ghost-v9']), 'unknown_asset');
});

test('supersede creates an explicit new version linked to the old one', () => {
  const registry = new AssetRegistry();
  registry.register(createAsset({ id: 'voice-v1', kind: 'voice', label: 'Narrator', version: 'v1', payload: { language: 'my' } }));
  const v2 = registry.supersede('voice-v1', 'v2', { payload: { language: 'my', warmth: 'high' } });
  assert.equal(v2.version, 'v2');
  assert.equal(v2.supersedes, 'voice-v1');
  assert.notEqual(v2.id, 'voice-v1');
  assert.equal(registry.get('voice-v1').version, 'v1'); // old record untouched
  const history = registry.history('voice-v1');
  assert.deepEqual(history.map(a => a.version), ['v1', 'v2']);
  fails(() => registry.supersede('missing', 'v2'), 'unknown_asset');
  fails(() => registry.register(createAsset({ id: 'voice-v1', kind: 'voice', label: 'dup', version: 'v1' })), 'duplicate_asset_id');
});

test('registry round-trips through JSON preserving versions and history', () => {
  const registry = new AssetRegistry();
  registry.register(createAsset({ id: 'style-v1', kind: 'visual_style', label: 'Warm grade', version: 'v1', payload: { lighting: 'practical' } }));
  registry.supersede('style-v1', 'v2');
  registry.register(createAsset({ id: 'prop-v1', kind: 'prop', label: 'Guitar', version: 'v3' }));
  const snapshot = registry.toJSON();
  const restored = AssetRegistry.fromJSON(JSON.parse(JSON.stringify(snapshot)));
  assert.deepEqual(restored.toJSON(), snapshot);
  assert.deepEqual(restored.listByKind('visual_style').map(a => a.version).sort(), ['v1', 'v2']);
  assert.deepEqual(restored.history('style-v1').map(a => a.version), ['v1', 'v2']);
});

test('every documented kind registers', () => {
  const registry = new AssetRegistry();
  const ids = ASSET_KINDS.map((kind, i) => registry.register(
    createAsset({ id: `a-${i}`, kind, label: `${kind} label`, version: `v${i + 1}` })).id);
  assert.equal(ids.length, ASSET_KINDS.length);
  assert.equal(new Set(ids).size, ids.length);
});
