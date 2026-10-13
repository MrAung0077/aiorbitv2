// Pure graph tests: no network, no ffmpeg, no provider calls.
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID, createHash } from 'node:crypto';
import { DerivationGraph } from '../src/derivation.js';
import { MediaFailure } from '../src/contracts.js';

const fails = (fn, code) => assert.throws(fn, error => error instanceof MediaFailure && error.code === code);
const sha = seed => createHash('sha256').update(seed).digest('hex');

function recapGraph() {
  const g = new DerivationGraph();
  g.addArtifact('master', { kind: 'master_video', sha256: sha('master') });
  g.addArtifact('reel', { kind: 'vertical_reel', sha256: sha('reel') });
  g.addArtifact('captions', { kind: 'captions', sha256: sha('cap') });
  g.addArtifact('thumbnail', { kind: 'thumbnail', sha256: sha('thumb') });
  g.addArtifact('unrelated', { kind: 'master_video', sha256: sha('other') });
  g.derive('master', 'reel');
  g.derive('reel', 'captions');
  g.derive('master', 'thumbnail');
  return g;
}

test('only transitive dependents become stale; unrelated branches keep id, hash and state', () => {
  const g = recapGraph();
  const unrelatedBefore = JSON.stringify(g.nodes.get('unrelated'));
  const stale = g.sourceChanged('master', { sha256: sha('master2') });
  assert.deepEqual(stale, ['captions', 'reel', 'thumbnail']);
  assert.equal(g.state('master'), 'fresh');
  assert.equal(g.nodes.get('master').sha256, sha('master2'));
  for (const id of ['reel', 'captions', 'thumbnail']) assert.equal(g.state(id), 'stale');
  // Unrelated node is byte-identical: id, hash and state unchanged.
  assert.equal(JSON.stringify(g.nodes.get('unrelated')), unrelatedBefore);
  // Direct dependents of the reel do NOT escape to the thumbnail branch.
  assert.deepEqual(g.dependents('reel'), ['captions']);
  assert.deepEqual(g.dependents('master').sort(), ['captions', 'reel', 'thumbnail']);
});

test('rebuilding clears only the rebuilt node; the rest stays stale', () => {
  const g = recapGraph();
  g.sourceChanged('master', { sha256: sha('master2') });
  const stillStale = g.rebuilt('reel', { sha256: sha('reel2') });
  assert.equal(g.state('reel'), 'fresh');
  assert.equal(g.nodes.get('reel').sha256, sha('reel2'));
  assert.deepEqual(stillStale, ['captions']); // still-stale dependents of the reel
  assert.deepEqual(g.staleIds(), ['captions', 'thumbnail']);
  g.rebuilt('captions', { sha256: sha('cap2') });
  g.rebuilt('thumbnail', { sha256: sha('thumb2') });
  assert.deepEqual(g.staleIds(), []);
});

test('changing a mid-chain source stales only its own downstream', () => {
  const g = recapGraph();
  const stale = g.sourceChanged('reel', { sha256: sha('reel2') });
  assert.deepEqual(stale, ['captions']);
  assert.equal(g.state('master'), 'fresh');
  assert.equal(g.state('thumbnail'), 'fresh');
  assert.deepEqual(g.sources('captions'), ['reel']);
});

test('cycles, self-references and unknown nodes are rejected', () => {
  const g = recapGraph();
  fails(() => g.derive('captions', 'master'), 'derivation_cycle');
  fails(() => g.derive('master', 'master'), 'derivation_self_reference');
  fails(() => g.derive('master', 'missing'), 'unknown_derivation_node');
  fails(() => g.sourceChanged('missing'), 'unknown_derivation_node');
  fails(() => g.addArtifact('master'), 'duplicate_derivation_id');
  fails(() => g.addArtifact('bad', { sha256: 'not-a-hash' }), 'invalid_derivation_hash');
  // Idempotent re-declaration of an existing edge is fine.
  g.derive('master', 'reel');
  assert.deepEqual(g.dependents('master').sort(), ['captions', 'reel', 'thumbnail']);
});

test('graph round-trips through JSON with stable states', () => {
  const g = recapGraph();
  g.sourceChanged('master', { sha256: sha('master2') });
  const snapshot = g.toJSON();
  const restored = DerivationGraph.fromJSON(JSON.parse(JSON.stringify(snapshot)));
  assert.deepEqual(restored.toJSON(), snapshot);
  assert.deepEqual(restored.staleIds(), ['captions', 'reel', 'thumbnail']);
  assert.equal(restored.nodes.get('unrelated').sha256, sha('other'));
});

test('randomized smoke: staleness is exactly the transitive closure', () => {
  const g = new DerivationGraph();
  const ids = Array.from({ length: 12 }, () => randomUUID());
  ids.forEach(id => g.addArtifact(id));
  // Chain with two side branches; no cycles possible by construction.
  for (let i = 0; i < 7; i++) g.derive(ids[i], ids[i + 1]);
  g.derive(ids[2], ids[8]); g.derive(ids[8], ids[9]);
  g.derive(ids[4], ids[10]); g.derive(ids[10], ids[11]);
  const stale = g.sourceChanged(ids[2]);
  assert.deepEqual(stale, [ids[3], ids[4], ids[5], ids[6], ids[7], ids[8], ids[9], ids[10], ids[11]].sort());
  assert.equal(g.state(ids[0]), 'fresh');
  assert.equal(g.state(ids[1]), 'fresh');
});
