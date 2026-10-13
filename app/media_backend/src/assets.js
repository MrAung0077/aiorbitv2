// Production asset references for narrative / recap workflows.
//
// A minimal, versioned structure for the reusable production bible:
// character/person identity, reference images, voice identity, wardrobe,
// props, instruments, locations and visual style/lighting. Shots reference
// asset ids instead of repeating full descriptions (see timeline.js).
//
// Honest scope: these records capture production *intent* so a human or a
// future selective-repair step can see what a shot was supposed to use.
// They do NOT guarantee that any generative model will stay consistent
// with them — no claim otherwise is made here or downstream.
//
// Versions are explicit: superseding an asset creates a new record with a
// new id and version string linked via `supersedes`. Pure, deterministic,
// JSON-serializable, no network.

import { randomUUID } from 'node:crypto';
import { MediaFailure, requireValue } from './contracts.js';

export const ASSET_KINDS = Object.freeze([
  'person',          // character / person identity (face, hair, build descriptors)
  'image_reference', // reference still, keyed by artifact id
  'voice',           // narration / dialogue voice identity
  'wardrobe',        // clothing / costume
  'prop',            // handheld or set props
  'instrument',      // musical instruments
  'location',        // set / location
  'visual_style',    // lighting, grade, lens language
]);

const VERSION_PATTERN = /^[A-Za-z0-9._-]{1,40}$/;

function assetId(id) {
  requireValue(typeof id === 'string' && id.length > 0 && id.length <= 120, 'invalid_asset_id', 'asset_validation');
  return id;
}

// payload is a small plain descriptor object, e.g.
// { artifactId, descriptors: ['long black hair', 'beanie'] } for a person,
// { artifactIds: [...] } for image_reference,
// { voiceProfile, language } for a voice,
// { description, palette } for wardrobe / location / visual_style.
// Raw bytes are never stored here; heavy media lives in artifacts.
export function createAsset({ id = randomUUID(), kind, label, version, payload = {}, supersedes = null } = {}) {
  id = assetId(id);
  requireValue(ASSET_KINDS.includes(kind), 'invalid_asset_kind', 'asset_validation');
  requireValue(typeof label === 'string' && label.trim().length > 0 && label.length <= 200, 'invalid_asset_label', 'asset_validation');
  requireValue(typeof version === 'string' && VERSION_PATTERN.test(version), 'invalid_asset_version', 'asset_validation');
  requireValue(payload !== null && typeof payload === 'object' && !Array.isArray(payload), 'invalid_asset_payload', 'asset_validation');
  requireValue(supersedes === null || typeof supersedes === 'string', 'invalid_asset_supersedes', 'asset_validation');
  return { id, kind, label: label.trim(), version, payload: structuredClone(payload), supersedes,
    createdAt: new Date().toISOString() };
}

export class AssetRegistry {
  constructor() { this.assets = new Map(); }
  register(asset = createAsset()) {
    if (this.assets.has(asset.id)) throw new MediaFailure('duplicate_asset_id', 'asset_validation', 400);
    if (asset.supersedes && !this.assets.has(asset.supersedes)) {
      throw new MediaFailure('unknown_superseded_asset', 'asset_validation', 400);
    }
    this.assets.set(asset.id, structuredClone(asset));
    return this.assets.get(asset.id);
  }
  // Convenience: version an existing asset without retyping its descriptor.
  // The caller supplies the new explicit version string.
  supersede(id, version, overrides = {}) {
    const current = this.assets.get(assetId(id));
    if (!current) throw new MediaFailure('unknown_asset', 'asset_validation', 400);
    return this.register(createAsset({ kind: current.kind, label: overrides.label ?? current.label,
      version, payload: overrides.payload ?? current.payload, supersedes: current.id }));
  }
  get(id) {
    const asset = this.assets.get(assetId(id));
    if (!asset) throw new MediaFailure('unknown_asset', 'asset_validation', 400);
    return asset;
  }
  listByKind(kind) {
    requireValue(ASSET_KINDS.includes(kind), 'invalid_asset_kind', 'asset_validation');
    return [...this.assets.values()].filter(a => a.kind === kind);
  }
  // Newest-first history of one asset line, following the supersedes chain.
  history(id) {
    const tip = this.get(id);
    const chain = [tip];
    const bySuperseded = new Map();
    for (const asset of this.assets.values()) if (asset.supersedes) bySuperseded.set(asset.supersedes, asset);
    let next = bySuperseded.get(tip.id);
    while (next) { chain.push(next); next = bySuperseded.get(next.id); }
    return chain;
  }
  // Resolve every asset id a shot references; unknown ids fail loudly so a
  // timeline can never silently point at a missing production asset.
  resolveAll(ids) {
    requireValue(Array.isArray(ids), 'invalid_asset_references', 'asset_validation');
    return ids.map(id => this.get(id));
  }
  toJSON() { return { version: 1, assets: [...this.assets.values()] }; }
  static fromJSON(data) {
    requireValue(data && data.version === 1 && Array.isArray(data.assets), 'invalid_asset_snapshot', 'asset_validation');
    const registry = new AssetRegistry();
    // Snapshots from toJSON() are in registration order, so every supersedes
    // target is already present. Anything else is a corrupt snapshot.
    for (const raw of data.assets) {
      if (raw.supersedes && !registry.assets.has(raw.supersedes)) {
        throw new MediaFailure('invalid_asset_snapshot', 'asset_validation', 400);
      }
      const { createdAt, ...fields } = raw;
      registry.register(createAsset(fields));
      registry.assets.get(raw.id).createdAt = createdAt;
    }
    return registry;
  }
}
