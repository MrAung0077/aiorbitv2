// Master -> derivative dependency tracking with selective staleness.
//
// Tracks relationships like: master video -> vertical reel -> captions ->
// thumbnail. When a source artifact changes, only its transitive dependents
// become stale; unrelated branches keep their ids, hashes and state.
//
// This module records derivation structure and staleness only. It does NOT
// regenerate anything: a future workflow step decides what to rebuild from
// the stale set. Pure, deterministic, JSON-serializable, no network.

import { MediaFailure, requireValue } from './contracts.js';

const STATES = new Set(['fresh', 'stale']);

function artifactId(id) {
  requireValue(typeof id === 'string' && id.length > 0 && id.length <= 120, 'invalid_derivation_id', 'derivation_validation');
  return id;
}

export class DerivationGraph {
  constructor() {
    // id -> { id, kind, sha256, state }; edges: source id -> Set(derivative ids)
    this.nodes = new Map();
    this.edges = new Map();
  }
  addArtifact(id, { kind = 'artifact', sha256 = null, state = 'fresh' } = {}) {
    id = artifactId(id);
    requireValue(typeof kind === 'string' && kind.length > 0 && kind.length <= 80, 'invalid_derivation_kind', 'derivation_validation');
    requireValue(sha256 === null || (typeof sha256 === 'string' && /^[0-9a-f]{64}$/.test(sha256)),
      'invalid_derivation_hash', 'derivation_validation');
    requireValue(STATES.has(state), 'invalid_derivation_state', 'derivation_validation');
    if (this.nodes.has(id)) throw new MediaFailure('duplicate_derivation_id', 'derivation_validation', 400);
    this.nodes.set(id, { id, kind, sha256, state });
    this.edges.set(id, new Set());
    return this.nodes.get(id);
  }
  // Record that `derivativeId` was produced from `sourceId`. Idempotent.
  derive(sourceId, derivativeId) {
    sourceId = artifactId(sourceId); derivativeId = artifactId(derivativeId);
    requireValue(this.nodes.has(sourceId) && this.nodes.has(derivativeId), 'unknown_derivation_node', 'derivation_validation');
    requireValue(sourceId !== derivativeId, 'derivation_self_reference', 'derivation_validation');
    // Adding sourceId -> derivativeId must not create a cycle back to sourceId.
    requireValue(!this.dependents(derivativeId).includes(sourceId), 'derivation_cycle', 'derivation_validation');
    this.edges.get(sourceId).add(derivativeId);
    return this;
  }
  // Transitive dependents, sorted for determinism.
  dependents(id) {
    id = artifactId(id);
    requireValue(this.nodes.has(id), 'unknown_derivation_node', 'derivation_validation');
    const seen = new Set(), stack = [...this.edges.get(id)];
    while (stack.length) {
      const next = stack.pop();
      if (seen.has(next)) continue;
      seen.add(next);
      stack.push(...this.edges.get(next));
    }
    return [...seen].sort();
  }
  sources(id) {
    id = artifactId(id);
    requireValue(this.nodes.has(id), 'unknown_derivation_node', 'derivation_validation');
    const found = [];
    for (const [source, targets] of this.edges) if (targets.has(id)) found.push(source);
    return found.sort();
  }
  state(id) {
    id = artifactId(id);
    const node = this.nodes.get(id);
    if (!node) throw new MediaFailure('unknown_derivation_node', 'derivation_validation', 400);
    return node.state;
  }
  // A source artifact changed (e.g. a timeline segment was repaired and the
  // master re-rendered). The source itself is fresh at its new hash; every
  // transitive dependent becomes stale. Returns the stale ids, sorted.
  sourceChanged(id, { sha256 = null } = {}) {
    id = artifactId(id);
    const node = this.nodes.get(id);
    if (!node) throw new MediaFailure('unknown_derivation_node', 'derivation_validation', 400);
    requireValue(sha256 === null || (typeof sha256 === 'string' && /^[0-9a-f]{64}$/.test(sha256)),
      'invalid_derivation_hash', 'derivation_validation');
    node.sha256 = sha256; node.state = 'fresh';
    const stale = this.dependents(id);
    for (const dependent of stale) this.nodes.get(dependent).state = 'stale';
    return stale;
  }
  // A derivative was rebuilt from its (now fresh) sources. Rebuilding while
  // any DIRECT source is still stale is rejected deterministically: a
  // derivative is only as fresh as the sources it was actually built from.
  // Clears only this node's stale flag; other stale nodes stay stale until
  // they are rebuilt too. This records freshness only; it does NOT
  // regenerate anything.
  rebuilt(id, { sha256 = null } = {}) {
    id = artifactId(id);
    const node = this.nodes.get(id);
    if (!node) throw new MediaFailure('unknown_derivation_node', 'derivation_validation', 400);
    requireValue(sha256 === null || (typeof sha256 === 'string' && /^[0-9a-f]{64}$/.test(sha256)),
      'invalid_derivation_hash', 'derivation_validation');
    const staleSources = this.sources(id).filter(source => this.nodes.get(source).state === 'stale');
    if (staleSources.length) {
      throw new MediaFailure('derivation_source_stale', 'derivation_validation', 400);
    }
    node.sha256 = sha256; node.state = 'fresh';
    return this.dependents(id).filter(dependent => this.nodes.get(dependent).state === 'stale');
  }
  staleIds() { return [...this.nodes.values()].filter(n => n.state === 'stale').map(n => n.id).sort(); }
  toJSON() {
    return { version: 1,
      nodes: [...this.nodes.values()].map(n => ({ ...n })),
      edges: [...this.edges.entries()].map(([source, targets]) => ({ source, derivatives: [...targets].sort() })) };
  }
  static fromJSON(data) {
    requireValue(data && data.version === 1 && Array.isArray(data.nodes) && Array.isArray(data.edges),
      'invalid_derivation_snapshot', 'derivation_validation');
    const graph = new DerivationGraph();
    for (const node of data.nodes) graph.addArtifact(node.id, { kind: node.kind, sha256: node.sha256, state: node.state });
    for (const edge of data.edges) for (const derivative of edge.derivatives) graph.derive(edge.source, derivative);
    return graph;
  }
}
