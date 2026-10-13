// Timeline-addressable media model for narrative / recap workflows.
//
// Provider-neutral, in-memory, JSON-serializable. A master media item owns
// scenes, shots, transcript segments, captions and narration segments, each
// addressable by stable id and a validated [startSeconds, endSeconds) range.
// The model is deliberately additive: replacing one segment (selective
// repair) never rewrites its siblings. Persistence is left to the caller
// (e.g. a future media_jobs table); this module only validates structure.
//
// Time ranges are validated with millisecond precision. Invalid ranges,
// unknown parents and out-of-bounds children are rejected with MediaFailure
// (stage 'timeline_validation', HTTP 400).

import { randomUUID } from 'node:crypto';
import { MediaFailure, requireValue } from './contracts.js';

const MAX_SECONDS = 12 * 60 * 60; // 12h hard ceiling; narrative masters are minutes long.

function seconds(value, field) {
  requireValue(typeof value === 'number' && Number.isFinite(value), 'invalid_time_range', 'timeline_validation');
  return value;
}

export function validateTimeRange(startSeconds, endSeconds, { maxSeconds = MAX_SECONDS } = {}) {
  const start = seconds(startSeconds, 'startSeconds');
  const end = seconds(endSeconds, 'endSeconds');
  requireValue(start >= 0 && end > start && end <= maxSeconds, 'invalid_time_range', 'timeline_validation');
  return { startSeconds: start, endSeconds: end };
}

function base({ id, startSeconds, endSeconds, sourceArtifactIds = [] }) {
  const range = validateTimeRange(startSeconds, endSeconds);
  requireValue(typeof id === 'string' && id.length > 0 && id.length <= 120, 'invalid_timeline_id', 'timeline_validation');
  requireValue(Array.isArray(sourceArtifactIds) && sourceArtifactIds.every(s => typeof s === 'string'),
    'invalid_source_artifacts', 'timeline_validation');
  return { id, ...range, sourceArtifactIds: [...sourceArtifactIds] };
}

function text(value, max, code) {
  requireValue(typeof value === 'string' && value.trim().length > 0 && value.length <= max, code, 'timeline_validation');
  return value;
}

// The ingested user-owned video (or audio) everything else is cut against.
export function masterMedia({ id = randomUUID(), artifactId, durationSeconds, width = null, height = null, mediaType = 'video' } = {}) {
  requireValue(typeof artifactId === 'string' && artifactId.length > 0, 'invalid_master_artifact', 'timeline_validation');
  const duration = seconds(durationSeconds, 'durationSeconds');
  requireValue(duration > 0 && duration <= MAX_SECONDS, 'invalid_time_range', 'timeline_validation');
  requireValue(['video', 'audio'].includes(mediaType), 'invalid_master_media_type', 'timeline_validation');
  for (const dim of [width, height]) requireValue(dim === null || (Number.isInteger(dim) && dim > 0), 'invalid_master_dimensions', 'timeline_validation');
  return { kind: 'master', id, artifactId, durationSeconds: duration, width, height, mediaType };
}

// A narrative beat of the master, e.g. "the argument", "the twist reveal".
export function scene({ id = randomUUID(), masterId, index, startSeconds, endSeconds, label = '', sourceArtifactIds = [] } = {}) {
  requireValue(typeof masterId === 'string' && masterId.length > 0, 'invalid_timeline_parent', 'timeline_validation');
  requireValue(Number.isInteger(index) && index >= 0, 'invalid_timeline_index', 'timeline_validation');
  requireValue(typeof label === 'string' && label.length <= 300, 'invalid_scene_label', 'timeline_validation');
  return { kind: 'scene', ...base({ id, startSeconds, endSeconds, sourceArtifactIds }), masterId, index, label };
}

// One continuous camera take inside a scene. References production asset ids
// (character, wardrobe, location, ...) rather than repeating descriptions.
export function shot({ id = randomUUID(), sceneId, index, startSeconds, endSeconds, assetIds = [], camera = '', sourceArtifactIds = [] } = {}) {
  requireValue(typeof sceneId === 'string' && sceneId.length > 0, 'invalid_timeline_parent', 'timeline_validation');
  requireValue(Number.isInteger(index) && index >= 0, 'invalid_timeline_index', 'timeline_validation');
  requireValue(typeof camera === 'string' && camera.length <= 300, 'invalid_shot_camera', 'timeline_validation');
  requireValue(Array.isArray(assetIds) && assetIds.every(s => typeof s === 'string'), 'invalid_asset_references', 'timeline_validation');
  return { kind: 'shot', ...base({ id, startSeconds, endSeconds, sourceArtifactIds }), sceneId, index, assetIds: [...assetIds], camera };
}

// Timed transcript of the master audio (from ASR or user-supplied; canonical
// lyrics/transcripts are never silently replaced — see song_routing policy).
export function transcriptSegment({ id = randomUUID(), masterId, startSeconds, endSeconds, text: words, speaker = '', sourceArtifactIds = [] } = {}) {
  requireValue(typeof masterId === 'string' && masterId.length > 0, 'invalid_timeline_parent', 'timeline_validation');
  requireValue(typeof speaker === 'string' && speaker.length <= 120, 'invalid_transcript_speaker', 'timeline_validation');
  return { kind: 'transcript', ...base({ id, startSeconds, endSeconds, sourceArtifactIds }), masterId,
    text: text(words, 2000, 'invalid_transcript_text'), speaker };
}

// Timed caption line for burn-in or sidecar export.
export function caption({ id = randomUUID(), masterId, startSeconds, endSeconds, text: line, style = 'default', sourceArtifactIds = [] } = {}) {
  requireValue(typeof masterId === 'string' && masterId.length > 0, 'invalid_timeline_parent', 'timeline_validation');
  requireValue(typeof style === 'string' && style.length <= 80, 'invalid_caption_style', 'timeline_validation');
  return { kind: 'caption', ...base({ id, startSeconds, endSeconds, sourceArtifactIds }), masterId,
    text: text(line, 500, 'invalid_caption_text'), style };
}

// A narration/voiceover segment mixed over the master timeline.
export function narrationSegment({ id = randomUUID(), masterId, startSeconds, endSeconds, voiceAssetId = null, text: line, sourceArtifactIds = [] } = {}) {
  requireValue(typeof masterId === 'string' && masterId.length > 0, 'invalid_timeline_parent', 'timeline_validation');
  requireValue(voiceAssetId === null || (typeof voiceAssetId === 'string' && voiceAssetId.length > 0),
    'invalid_voice_reference', 'timeline_validation');
  return { kind: 'narration', ...base({ id, startSeconds, endSeconds, sourceArtifactIds }), masterId, voiceAssetId,
    text: text(line, 2000, 'invalid_narration_text') };
}

const kinds = { master: 'masters', scene: 'scenes', shot: 'shots', transcript: 'transcripts', caption: 'captions', narration: 'narrations' };

export class Timeline {
  constructor() {
    this.masters = new Map(); this.scenes = new Map(); this.shots = new Map();
    this.transcripts = new Map(); this.captions = new Map(); this.narrations = new Map();
  }
  _collection(kind) {
    const name = kinds[kind];
    if (!name) throw new MediaFailure('unknown_timeline_kind', 'timeline_validation', 400);
    return this[name];
  }
  _masterBounds(masterId) {
    const master = this.masters.get(masterId);
    if (!master) throw new MediaFailure('unknown_timeline_parent', 'timeline_validation', 400);
    return master.durationSeconds;
  }
  _checkInsideMaster(item, masterId) {
    const duration = this._masterBounds(masterId);
    requireValue(item.endSeconds <= duration, 'timeline_segment_out_of_bounds', 'timeline_validation');
  }
  addMaster(master = masterMedia()) {
    if (this.masters.has(master.id)) throw new MediaFailure('duplicate_timeline_id', 'timeline_validation', 400);
    this.masters.set(master.id, structuredClone(master));
    return this.masters.get(master.id);
  }
  _addChild(collection, item, parentId, parentKind) {
    if (collection.has(item.id)) throw new MediaFailure('duplicate_timeline_id', 'timeline_validation', 400);
    const parent = this._collection(parentKind).get(parentId);
    if (!parent) throw new MediaFailure('unknown_timeline_parent', 'timeline_validation', 400);
    const parentStart = parentKind === 'master' ? 0 : parent.startSeconds;
    const parentEnd = parentKind === 'master' ? parent.durationSeconds : parent.endSeconds;
    requireValue(item.startSeconds >= parentStart && item.endSeconds <= parentEnd,
      'timeline_segment_out_of_bounds', 'timeline_validation');
    collection.set(item.id, structuredClone(item));
    return collection.get(item.id);
  }
  addScene(sceneItem = scene()) {
    this._checkInsideMaster(sceneItem, sceneItem.masterId);
    return this._addChild(this.scenes, sceneItem, sceneItem.masterId, 'master');
  }
  addShot(shotItem = shot()) {
    const parentScene = this.scenes.get(shotItem.sceneId);
    if (!parentScene) throw new MediaFailure('unknown_timeline_parent', 'timeline_validation', 400);
    return this._addChild(this.shots, shotItem, shotItem.sceneId, 'scene');
  }
  addTranscript(segment = transcriptSegment()) {
    this._checkInsideMaster(segment, segment.masterId);
    if (this.transcripts.has(segment.id)) throw new MediaFailure('duplicate_timeline_id', 'timeline_validation', 400);
    this.transcripts.set(segment.id, structuredClone(segment));
    return this.transcripts.get(segment.id);
  }
  addCaption(item = caption()) {
    this._checkInsideMaster(item, item.masterId);
    if (this.captions.has(item.id)) throw new MediaFailure('duplicate_timeline_id', 'timeline_validation', 400);
    this.captions.set(item.id, structuredClone(item));
    return this.captions.get(item.id);
  }
  addNarration(item = narrationSegment()) {
    this._checkInsideMaster(item, item.masterId);
    if (this.narrations.has(item.id)) throw new MediaFailure('duplicate_timeline_id', 'timeline_validation', 400);
    this.narrations.set(item.id, structuredClone(item));
    return this.narrations.get(item.id);
  }
  // Selective repair: swap one segment for a corrected version. Siblings are
  // untouched; containment against the parent is re-validated.
  replace(kind, id, replacement) {
    const collection = this._collection(kind);
    const current = collection.get(id);
    if (!current) throw new MediaFailure('unknown_timeline_segment', 'timeline_validation', 400);
    requireValue(replacement && replacement.kind === kind && replacement.id === id, 'timeline_replace_mismatch', 'timeline_validation');
    if (kind === 'master') {
      const duration = seconds(replacement.durationSeconds, 'durationSeconds');
      requireValue(duration > 0 && duration <= MAX_SECONDS, 'invalid_time_range', 'timeline_validation');
    } else validateTimeRange(replacement.startSeconds, replacement.endSeconds);
    if (kind === 'scene') this._checkInsideMaster(replacement, replacement.masterId);
    else if (kind === 'shot') {
      const parentScene = this.scenes.get(replacement.sceneId);
      if (!parentScene) throw new MediaFailure('unknown_timeline_parent', 'timeline_validation', 400);
      requireValue(replacement.startSeconds >= parentScene.startSeconds && replacement.endSeconds <= parentScene.endSeconds,
        'timeline_segment_out_of_bounds', 'timeline_validation');
    } else if (kind !== 'master') this._checkInsideMaster(replacement, replacement.masterId);
    if (kind === 'master') requireValue(replacement.durationSeconds >= current.durationSeconds ||
      [...this.scenes.values()].every(s => s.masterId !== id || s.endSeconds <= replacement.durationSeconds),
      'timeline_master_shrink_conflict', 'timeline_validation');
    collection.set(id, structuredClone(replacement));
    return collection.get(id);
  }
  ordered(kind) {
    return [...this._collection(kind).values()].sort((a, b) =>
      (a.startSeconds - b.startSeconds) || (a.index ?? 0) - (b.index ?? 0));
  }
  toJSON() {
    const dump = map => [...map.values()];
    return { version: 1, masters: dump(this.masters), scenes: dump(this.scenes), shots: dump(this.shots),
      transcripts: dump(this.transcripts), captions: dump(this.captions), narrations: dump(this.narrations) };
  }
  static fromJSON(data) {
    requireValue(data && data.version === 1, 'invalid_timeline_snapshot', 'timeline_validation');
    const timeline = new Timeline();
    for (const master of data.masters ?? []) timeline.addMaster(masterMedia(master));
    for (const item of data.scenes ?? []) timeline.addScene(scene(item));
    for (const item of data.shots ?? []) timeline.addShot(shot(item));
    for (const item of data.transcripts ?? []) timeline.addTranscript(transcriptSegment(item));
    for (const item of data.captions ?? []) timeline.addCaption(caption(item));
    for (const item of data.narrations ?? []) timeline.addNarration(narrationSegment(item));
    return timeline;
  }
}
