// Pure model tests: no network, no ffmpeg, no provider calls.
import test from 'node:test';
import assert from 'node:assert/strict';
import { Timeline, masterMedia, scene, shot, transcriptSegment, caption, narrationSegment, validateTimeRange } from '../src/timeline.js';
import { MediaFailure } from '../src/contracts.js';

const fails = (fn, code) => assert.throws(fn, error => error instanceof MediaFailure && error.code === code);

test('invalid time ranges are rejected', () => {
  fails(() => validateTimeRange(-1, 5), 'invalid_time_range');
  fails(() => validateTimeRange(5, 5), 'invalid_time_range');
  fails(() => validateTimeRange(9, 5), 'invalid_time_range');
  fails(() => validateTimeRange(NaN, 5), 'invalid_time_range');
  fails(() => validateTimeRange(0, Infinity), 'invalid_time_range');
  fails(() => validateTimeRange(0, 12 * 3600 + 1), 'invalid_time_range');
  assert.deepEqual(validateTimeRange(1.5, 90.25), { startSeconds: 1.5, endSeconds: 90.25 });
});

test('scene and shot containment is enforced', () => {
  const timeline = new Timeline();
  const master = timeline.addMaster(masterMedia({ artifactId: 'a1', durationSeconds: 120 }));
  fails(() => timeline.addScene(scene({ masterId: master.id, index: 0, startSeconds: 100, endSeconds: 130 })), 'timeline_segment_out_of_bounds');
  fails(() => timeline.addScene(scene({ masterId: 'missing', index: 0, startSeconds: 0, endSeconds: 10 })), 'unknown_timeline_parent');
  const opening = timeline.addScene(scene({ masterId: master.id, index: 0, startSeconds: 0, endSeconds: 60, label: 'Opening' }));
  fails(() => timeline.addShot(shot({ sceneId: opening.id, index: 0, startSeconds: 50, endSeconds: 70 })), 'timeline_segment_out_of_bounds');
  fails(() => timeline.addShot(shot({ sceneId: 'missing', index: 0, startSeconds: 0, endSeconds: 5 })), 'unknown_timeline_parent');
  const take = timeline.addShot(shot({ sceneId: opening.id, index: 0, startSeconds: 0, endSeconds: 10, assetIds: ['person-v1'] }));
  assert.equal(take.sceneId, opening.id);
  assert.deepEqual(take.assetIds, ['person-v1']);
});

test('text, speaker and voice references are validated', () => {
  const timeline = new Timeline();
  const master = timeline.addMaster(masterMedia({ artifactId: 'a1', durationSeconds: 60 }));
  fails(() => timeline.addCaption(caption({ masterId: master.id, startSeconds: 0, endSeconds: 2, text: '   ' })), 'invalid_caption_text');
  fails(() => timeline.addTranscript(transcriptSegment({ masterId: master.id, startSeconds: 0, endSeconds: 2, text: '' })), 'invalid_transcript_text');
  fails(() => timeline.addNarration(narrationSegment({ masterId: master.id, startSeconds: 0, endSeconds: 2, text: 'ok', voiceAssetId: 42 })), 'invalid_voice_reference');
  const line = timeline.addCaption(caption({ masterId: master.id, startSeconds: 0, endSeconds: 2, text: 'Hello', sourceArtifactIds: ['seg-1'] }));
  assert.equal(line.text, 'Hello');
  assert.deepEqual(line.sourceArtifactIds, ['seg-1']);
});

test('duplicate ids and cross-master leaks are rejected', () => {
  const timeline = new Timeline();
  const first = timeline.addMaster(masterMedia({ id: 'm1', artifactId: 'a1', durationSeconds: 60 }));
  fails(() => timeline.addMaster(masterMedia({ id: 'm1', artifactId: 'a2', durationSeconds: 60 })), 'duplicate_timeline_id');
  const s1 = timeline.addScene(scene({ id: 's1', masterId: first.id, index: 0, startSeconds: 0, endSeconds: 30 }));
  fails(() => timeline.addScene(scene({ id: 's1', masterId: first.id, index: 1, startSeconds: 30, endSeconds: 60 })), 'duplicate_timeline_id');
  assert.equal(s1.masterId, 'm1');
});

test('selective repair replaces one segment and leaves siblings untouched', () => {
  const timeline = new Timeline();
  const master = timeline.addMaster(masterMedia({ artifactId: 'a1', durationSeconds: 100 }));
  timeline.addScene(scene({ id: 's1', masterId: master.id, index: 0, startSeconds: 0, endSeconds: 50, label: 'before' }));
  const keep = timeline.addShot(shot({ id: 'keep', sceneId: 's1', index: 0, startSeconds: 0, endSeconds: 10 }));
  timeline.addShot(shot({ id: 'fix', sceneId: 's1', index: 1, startSeconds: 10, endSeconds: 20, camera: 'wide' }));
  const before = JSON.stringify(timeline.toJSON());
  timeline.replace('shot', 'fix', shot({ id: 'fix', sceneId: 's1', index: 1, startSeconds: 10, endSeconds: 22, camera: 'close-up' }));
  assert.equal(timeline.shots.get('fix').camera, 'close-up');
  assert.equal(timeline.shots.get('fix').endSeconds, 22);
  assert.deepEqual(timeline.shots.get('keep'), keep); // sibling byte-identical
  assert.ok(!before.includes('close-up'));
  fails(() => timeline.replace('shot', 'fix', shot({ id: 'fix', sceneId: 's1', index: 1, startSeconds: 10, endSeconds: 60, camera: 'x' })), 'timeline_segment_out_of_bounds');
  fails(() => timeline.replace('shot', 'missing', shot({ id: 'missing', sceneId: 's1', index: 2, startSeconds: 20, endSeconds: 30 })), 'unknown_timeline_segment');
});

test('master shrink is rejected while scenes overflow it', () => {
  const timeline = new Timeline();
  const master = timeline.addMaster(masterMedia({ id: 'm1', artifactId: 'a1', durationSeconds: 100 }));
  timeline.addScene(scene({ masterId: 'm1', index: 0, startSeconds: 0, endSeconds: 90 }));
  fails(() => timeline.replace('master', 'm1', masterMedia({ id: 'm1', artifactId: 'a1', durationSeconds: 80 })), 'timeline_master_shrink_conflict');
  timeline.replace('master', 'm1', masterMedia({ id: 'm1', artifactId: 'a1', durationSeconds: 120 }));
  assert.equal(timeline.masters.get('m1').durationSeconds, 120);
});

test('timeline round-trips through JSON with stable ids', () => {
  const timeline = new Timeline();
  const master = timeline.addMaster(masterMedia({ artifactId: 'a1', durationSeconds: 90, width: 1920, height: 1080 }));
  const opening = timeline.addScene(scene({ masterId: master.id, index: 0, startSeconds: 0, endSeconds: 45, label: 'Cold open' }));
  timeline.addShot(shot({ sceneId: opening.id, index: 0, startSeconds: 0, endSeconds: 8, assetIds: ['person-v1', 'location-v2'] }));
  timeline.addTranscript(transcriptSegment({ masterId: master.id, startSeconds: 0, endSeconds: 8, text: 'Previously…', speaker: 'Narrator' }));
  timeline.addCaption(caption({ masterId: master.id, startSeconds: 0, endSeconds: 8, text: 'Previously…' }));
  timeline.addNarration(narrationSegment({ masterId: master.id, startSeconds: 0, endSeconds: 8, text: 'Previously…', voiceAssetId: 'voice-v1' }));
  const snapshot = timeline.toJSON();
  const restored = Timeline.fromJSON(JSON.parse(JSON.stringify(snapshot)));
  assert.deepEqual(restored.toJSON(), snapshot);
  assert.deepEqual(restored.ordered('scene').map(s => s.label), ['Cold open']);
});
