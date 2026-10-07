import { DatabaseSync } from 'node:sqlite';
import { mkdirSync, readFileSync, writeFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { createHash, randomUUID } from 'node:crypto';
import { MediaFailure, defaultArtist, requireValue } from './contracts.js';
import { songPreferences } from './song_routing.js';
import { initializeProvenance, approveFinal, publicProvenanceSummary } from './creative_provenance.js';
import { MediaJobs } from './media_jobs.js';

export class MediaStore {
  constructor(root, options = {}) {
    this.root = root;
    mkdirSync(root, { recursive: true, mode: 0o700 });
    this.db = new DatabaseSync(join(root, 'media.sqlite'));
    this.db.exec(`PRAGMA busy_timeout=5000; PRAGMA journal_mode=WAL;
      CREATE TABLE IF NOT EXISTS artists(owner TEXT PRIMARY KEY, payload TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS visuals(id TEXT PRIMARY KEY, owner TEXT NOT NULL, path TEXT NOT NULL, width INTEGER, height INTEGER);
      CREATE TABLE IF NOT EXISTS projects(id TEXT PRIMARY KEY, owner TEXT NOT NULL, request_id TEXT NOT NULL, payload TEXT NOT NULL, UNIQUE(owner, request_id));`);
    this.jobs = new MediaJobs(this, options);
  }
  close() { this.db.close(); }
  artist(owner) { const row = this.db.prepare('SELECT payload FROM artists WHERE owner=?').get(owner); return row ? JSON.parse(row.payload) : structuredClone(defaultArtist); }
  saveArtist(owner, input) {
    requireValue(typeof input.artistName === 'string' && /^[\p{L}\p{N} .'-]{1,60}$/u.test(input.artistName));
    requireValue(Array.isArray(input.visualReferenceIds) && input.visualReferenceIds.length === 4 && new Set(input.visualReferenceIds).size === 4);
    for (const id of input.visualReferenceIds) requireValue(this.visual(owner, id), 'invalid_visual');
    requireValue(input.permissionsDeclared === undefined || typeof input.permissionsDeclared === 'boolean');
    const artist = { ...defaultArtist, artistName: input.artistName, visualReferenceIds: input.visualReferenceIds,
      permissionsDeclared: input.permissionsDeclared === true };
    this.db.prepare('INSERT OR REPLACE INTO artists VALUES (?,?)').run(owner, JSON.stringify(artist));
    return artist;
  }
  visual(owner, id) { return this.db.prepare('SELECT * FROM visuals WHERE id=? AND owner=?').get(id, owner); }
  addVisual(owner, id, path, size) { this.db.prepare('INSERT INTO visuals VALUES (?,?,?,?,?)').run(id, owner, path, size.width, size.height); }
  list(owner) { return this.db.prepare('SELECT payload FROM projects WHERE owner=? ORDER BY rowid DESC LIMIT 100').all(owner).map(row => JSON.parse(row.payload)); }
  get(owner, id) { const row = this.db.prepare('SELECT payload FROM projects WHERE id=? AND owner=?').get(id, owner); return row ? JSON.parse(row.payload) : null; }
  getById(id) { const row = this.db.prepare('SELECT payload FROM projects WHERE id=?').get(id); return row ? JSON.parse(row.payload) : null; }
  submission(owner, requestId) { return this.db.prepare('SELECT id FROM projects WHERE owner=? AND request_id=?').get(owner, requestId); }
  save(project) { this.db.prepare('UPDATE projects SET payload=? WHERE id=? AND owner=?').run(JSON.stringify(project), project.projectId, project.owner); }
  create(owner, input) {
    return this.jobs.transaction(() => this.createInTransaction(owner, input));
  }
  createInTransaction(owner, input) {
    const preferences = songPreferences(input.preferences);
    requireValue(input.commercialUseRequested === undefined || typeof input.commercialUseRequested === 'boolean');
    requireValue(input.imagePermissionsDeclared === undefined || typeof input.imagePermissionsDeclared === 'boolean');
    requireValue(typeof input.requestId === 'string' && /^[a-f0-9-]{36}$/.test(input.requestId));
    requireValue(['en', 'my'].includes(input.language));
    requireValue(typeof input.goal === 'string' && input.goal.trim().length >= 8 && input.goal.length <= 4000);
    const duplicate = this.db.prepare('SELECT payload FROM projects WHERE owner=? AND request_id=?').get(owner, input.requestId);
    if (duplicate) {
      const project = JSON.parse(duplicate.payload);
      requireValue(project.goal === input.goal.trim() && project.language === input.language, 'idempotency_conflict');
      requireValue(JSON.stringify(songPreferences(project.preferences)) === JSON.stringify(preferences), 'idempotency_conflict');
      requireValue((project.commercialUseRequested ?? false) === (input.commercialUseRequested ?? false), 'idempotency_conflict');
      if (project.submissionSnapshot) requireValue(project.submissionSnapshot.imagePermissionsDeclared === (input.imagePermissionsDeclared ?? false), 'idempotency_conflict');
      return project;
    }
    // Separate personal-media admission guard; existing Chat quotas are untouched.
    const existing = this.list(owner);
    if (existing.some(p => ['queued', 'specifying', 'generating', 'rendering'].includes(p.status))) throw new MediaFailure('media_job_active', 'admission', 409);
    const today = new Date().toISOString().slice(0, 10);
    if (existing.filter(p => p.createdAt.startsWith(today)).length >= 2) throw new MediaFailure('media_daily_limit', 'admission', 429);
    const artist = this.artist(owner);
    requireValue(artist.visualReferenceIds.length === 4, 'four_artist_visuals_required');
    const project = { projectId: randomUUID(), owner, requestId: input.requestId, goal: input.goal.trim(), language: input.language,
      artist, preferences, title: '', genre: '', mood: '', tempoDirection: '', theme: '', lyrics: '', musicPrompt: '',
      audioArtifact: null, videoArtifacts: [], artifacts: [], status: 'queued', createdAt: new Date().toISOString(), failure: null };
    initializeProvenance(project, input);
    project.submissionSnapshot = { goal: input.goal.trim(), language: input.language, preferences,
      commercialUseRequested: input.commercialUseRequested ?? false, imagePermissionsDeclared: input.imagePermissionsDeclared ?? false };
    this.db.prepare('INSERT INTO projects VALUES (?,?,?,?)').run(project.projectId, owner, input.requestId, JSON.stringify(project));
    this.jobs.ensure(project);
    return project;
  }
  approve(owner, id, input) {
    const project = this.get(owner, id);
    if (!project) throw new MediaFailure('not_found', 'lookup', 404);
    requireValue(input.action === 'approve_final', 'invalid_project_action');
    approveFinal(project, input.selectedArtifactIds);
    this.save(project);
    return project;
  }
  next() { return this.db.prepare('SELECT payload FROM projects ORDER BY rowid').all().map(r => JSON.parse(r.payload)).find(p => p.status === 'queued'); }
  interruptUncertain() {
    for (const row of this.db.prepare('SELECT payload FROM projects').all()) {
      const p = JSON.parse(row.payload);
      const job = this.jobs.forProject(p.projectId);
      if (p.status === 'queued' && !job) this.jobs.transaction(() => this.jobs.ensure(p));
      if (job && (job.lease_token || Object.keys(job.payload.checkpoints).length)) continue;
      if (['specifying', 'generating', 'rendering'].includes(p.status)) {
        p.status = 'interrupted'; p.failure = { code: 'interrupted_no_auto_retry', stage: 'recovery' }; this.save(p);
        if (job) this.db.prepare("UPDATE media_jobs SET status='uncertain' WHERE id=?").run(job.id);
      }
    }
  }
  directory(project) { const path = join(this.root, project.projectId); mkdirSync(path, { recursive: true, mode: 0o700 }); return path; }
  artifact(project, fileName, mimeType, extra = {}) {
    const path = join(this.directory(project), fileName);
    const size = statSync(path).size;
    requireValue(size > 0 && size <= 256 * 1024 * 1024, 'invalid_artifact_size', 'artifact_validation');
    const bytes = readFileSync(path);
    const item = { id: randomUUID(), versionId: randomUUID(), fileName, mimeType, byteSize: size,
      sha256: createHash('sha256').update(bytes).digest('hex'), ...extra };
    project.artifacts.push(item); this.save(project); return item;
  }
  write(project, fileName, content) { writeFileSync(join(this.directory(project), fileName), content, { flag: 'wx', mode: 0o600 }); }
}

export function publicProject(project) {
  const { owner, requestId, providerMetadata, provenance, manifest, submissionSnapshot, ...safe } = project;
  return { ...safe, provenanceSummary: publicProvenanceSummary(project) };
}
