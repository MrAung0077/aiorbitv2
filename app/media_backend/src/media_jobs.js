import { randomUUID, createHash } from 'node:crypto';
import { mkdirSync, existsSync, readFileSync, writeFileSync, renameSync, openSync, fsyncSync, closeSync } from 'node:fs';
import { join } from 'node:path';
import { MediaFailure } from './contracts.js';

const hash = value => createHash('sha256').update(value).digest('hex');
const encode = value => Buffer.isBuffer(value) || value instanceof Uint8Array
  ? { $mediaBytes: Buffer.from(value).toString('base64') }
  : Array.isArray(value) ? value.map(encode)
    : value && typeof value === 'object' ? Object.fromEntries(Object.entries(value).map(([k, v]) => [k, encode(v)])) : value;
const decode = value => value?.$mediaBytes ? Buffer.from(value.$mediaBytes, 'base64')
  : Array.isArray(value) ? value.map(decode)
    : value && typeof value === 'object' ? Object.fromEntries(Object.entries(value).map(([k, v]) => [k, decode(v)])) : value;

// Flush file contents before publication. SQLite runs with synchronous=FULL.
function durableWrite(path, bytes) {
  writeFileSync(path, bytes, { flag: 'wx', mode: 0o600 });
  const fd = openSync(path, 'r+');
  try { fsyncSync(fd); } finally { closeSync(fd); }
}

export class LeaseLost extends Error {}
export class PendingExecution extends Error {}
export class ReviewRequired extends MediaFailure {
  constructor(stage, code = 'provider_outcome_uncertain') { super(code, stage); }
}

export class MediaJobs {
  constructor(store, { clock = Date.now } = {}) {
    this.store = store; this.db = store.db; this.clock = clock;
    this.db.exec(`PRAGMA busy_timeout=5000; PRAGMA synchronous=FULL;
      CREATE TABLE IF NOT EXISTS media_jobs (
        id TEXT PRIMARY KEY, project_id TEXT NOT NULL UNIQUE, status TEXT NOT NULL,
        lease_owner TEXT, lease_token TEXT, lease_expiry INTEGER NOT NULL DEFAULT 0,
        ready_at INTEGER NOT NULL DEFAULT 0, payload TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS media_stages (
        id TEXT PRIMARY KEY, job_id TEXT NOT NULL, kind TEXT NOT NULL, payload TEXT NOT NULL, UNIQUE(job_id,kind));
      CREATE TABLE IF NOT EXISTS media_attempts (
        id TEXT PRIMARY KEY, stage_id TEXT NOT NULL, payload TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS media_artifacts (
        id TEXT PRIMARY KEY, stage_id TEXT NOT NULL, slot TEXT NOT NULL, payload TEXT NOT NULL, UNIQUE(stage_id,slot));
      CREATE TABLE IF NOT EXISTS media_outbox (
        id TEXT PRIMARY KEY, job_id TEXT NOT NULL UNIQUE, payload TEXT NOT NULL, delivered_at TEXT);
      CREATE INDEX IF NOT EXISTS media_jobs_ready ON media_jobs(status,ready_at,lease_expiry);`);
  }
  transaction(fn) {
    this.db.exec('BEGIN IMMEDIATE');
    try { const value = fn(); this.db.exec('COMMIT'); return value; }
    catch (error) { this.db.exec('ROLLBACK'); throw error; }
  }
  timestamp() { return new Date(this.clock()).toISOString(); }
  ensure(project) {
    const found = this.forProject(project.projectId); if (found) return found;
    const id = randomUUID();
    this.db.prepare('INSERT INTO media_jobs(id,project_id,status,payload) VALUES (?,?,?,?)')
      .run(id, project.projectId, 'queued', JSON.stringify({ createdAt: this.timestamp(), updatedAt: this.timestamp(), checkpoints: {} }));
    return this.get(id);
  }
  get(id) { const row = this.db.prepare('SELECT * FROM media_jobs WHERE id=?').get(id); return row ? { ...row, payload: JSON.parse(row.payload) } : null; }
  forProject(id) { const row = this.db.prepare('SELECT id FROM media_jobs WHERE project_id=?').get(id); return row ? this.get(row.id) : null; }
  claim(owner, { projectId = null, leaseMs = 30000 } = {}) {
    return this.transaction(() => {
      const row = this.db.prepare(`SELECT id FROM media_jobs WHERE status IN ('queued','running')
        AND lease_expiry<=? AND ready_at<=? AND (? IS NULL OR project_id=?) ORDER BY rowid LIMIT 1`)
        .get(this.clock(), this.clock(), projectId, projectId);
      if (!row) return null;
      const token = randomUUID();
      this.db.prepare("UPDATE media_jobs SET status='running',lease_owner=?,lease_token=?,lease_expiry=? WHERE id=?")
        .run(owner, token, this.clock() + leaseMs, row.id);
      return { jobId: row.id, owner, token, leaseMs };
    });
  }
  assertLease(lease) {
    const job = this.get(lease.jobId);
    if (!job || job.status !== 'running' || job.lease_owner !== lease.owner || job.lease_token !== lease.token || job.lease_expiry <= this.clock()) throw new LeaseLost();
    return job;
  }
  fenced(lease, fn) { return this.transaction(() => fn(this.assertLease(lease))); }
  renew(lease) {
    return this.fenced(lease, () => this.db.prepare('UPDATE media_jobs SET lease_expiry=? WHERE id=?').run(this.clock() + lease.leaseMs, lease.jobId));
  }
  release(lease, delay = 0) {
    this.fenced(lease, () => this.db.prepare("UPDATE media_jobs SET status='queued',lease_owner=NULL,lease_token=NULL,lease_expiry=0,ready_at=? WHERE id=?")
      .run(this.clock() + delay, lease.jobId));
  }
  stage(lease, kind, input, route) {
    return this.fenced(lease, job => {
      const row = this.db.prepare('SELECT payload FROM media_stages WHERE job_id=? AND kind=?').get(job.id, kind);
      if (row) return JSON.parse(row.payload);
      const stage = { id: randomUUID(), jobId: job.id, projectId: job.project_id, kind,
        createdAt: this.timestamp(), artifactId: randomUUID(), artifactVersionId: randomUUID() };
      const attempt = { id: randomUUID(), stageId: stage.id, jobId: job.id, projectId: job.project_id, stageType: kind,
        status: 'prepared', leaseOwner: lease.owner, leaseToken: lease.token, leaseExpiry: job.lease_expiry,
        routeSnapshot: structuredClone(route), inputSnapshot: structuredClone(input),
        providerId: route.providerId ?? null, model: route.model ?? null, apiVersion: route.apiVersion ?? null,
        workflowVersion: 'song-durable-v1', externalExecutionId: null, providerStatus: null, providerMetadata: null,
        billing: route.providerId === 'local' ? 'not_applicable' : 'not_dispatched', uncertainty: null,
        createdAt: this.timestamp(), startedAt: null, updatedAt: this.timestamp(), completedAt: null,
        failure: null, artifactIds: [], localFailures: 0 };
      stage.attemptId = attempt.id;
      this.db.prepare('INSERT INTO media_stages VALUES (?,?,?,?)').run(stage.id, job.id, kind, JSON.stringify(stage));
      this.db.prepare('INSERT INTO media_attempts VALUES (?,?,?)').run(attempt.id, stage.id, JSON.stringify(attempt));
      return stage;
    });
  }
  attempt(stage) { return JSON.parse(this.db.prepare('SELECT payload FROM media_attempts WHERE id=?').get(stage.attemptId).payload); }
  update(lease, stage, fields) {
    return this.fenced(lease, job => {
      const mutable = new Set(['status', 'billing', 'uncertainty', 'startedAt', 'completedAt', 'externalExecutionId',
        'providerStatus', 'providerMetadata', 'resultSha256', 'failure', 'localFailures', 'artifactIds']);
      if (Object.keys(fields).some(key => !mutable.has(key))) throw new Error('immutable_execution_snapshot');
      const attempt = this.attempt(stage);
      if (attempt.jobId !== job.id) throw new LeaseLost();
      Object.assign(attempt, fields, { updatedAt: this.timestamp(), leaseOwner: lease.owner, leaseToken: lease.token, leaseExpiry: job.lease_expiry });
      this.db.prepare('UPDATE media_attempts SET payload=? WHERE id=?').run(JSON.stringify(attempt), attempt.id);
      return attempt;
    });
  }
  checkpoint(lease, project, name, value = true) {
    this.fenced(lease, job => {
      if (project.projectId !== job.project_id) throw new LeaseLost();
      job.payload.checkpoints[name] = value; job.payload.updatedAt = this.timestamp();
      this.db.prepare('UPDATE media_jobs SET payload=? WHERE id=?').run(JSON.stringify(job.payload), job.id);
      this.store.save(project);
    });
  }
  terminal(lease, project, status) {
    this.fenced(lease, job => {
      if (project.projectId !== job.project_id) throw new LeaseLost();
      this.store.save(project);
      const completedAt = this.timestamp();
      job.payload.completedAt = completedAt; job.payload.updatedAt = completedAt;
      this.db.prepare('UPDATE media_jobs SET status=?,payload=?,lease_expiry=0,lease_token=NULL,lease_owner=NULL WHERE id=?')
        .run(status, JSON.stringify(job.payload), job.id);
      const event = { id: randomUUID(), jobId: job.id, projectId: project.projectId, type: 'media.terminal',
        status, reviewRequired: status === 'uncertain', artifactReady: project.artifacts.length > 0,
        artifactIds: project.artifacts.map(a => a.id), createdAt: completedAt };
      this.db.prepare('INSERT OR IGNORE INTO media_outbox(id,job_id,payload) VALUES (?,?,?)').run(event.id, job.id, JSON.stringify(event));
    });
  }
  events() { return this.db.prepare('SELECT payload FROM media_outbox WHERE delivered_at IS NULL ORDER BY rowid').all().map(r => JSON.parse(r.payload)); }
  async deliver(consumer) {
    // At-least-once delivery: a future consumer must deduplicate by event.id.
    for (const event of this.events()) {
      await consumer(event);
      this.db.prepare('UPDATE media_outbox SET delivered_at=? WHERE id=? AND delivered_at IS NULL').run(this.timestamp(), event.id);
    }
  }
}

export class SongExecution {
  constructor(store, lease, { hook = async () => {} } = {}) {
    this.store = store; this.jobs = store.jobs; this.lease = lease; this.hook = hook;
    this.project = store.getById(this.jobs.get(lease.jobId).project_id);
  }
  done(name) { return this.jobs.get(this.lease.jobId).payload.checkpoints[name]; }
  checkpoint(name, value = true) { this.jobs.checkpoint(this.lease, this.project, name, value); }
  source(kind) {
    const row = this.jobs.db.prepare('SELECT payload FROM media_stages WHERE job_id=? AND kind=?').get(this.lease.jobId, kind);
    const stage = JSON.parse(row.payload);
    return { sourceStageId: stage.id, sourceAttemptId: stage.attemptId };
  }
  linkOutput(kind, artifact) {
    const row = this.jobs.db.prepare('SELECT payload FROM media_stages WHERE job_id=? AND kind=?').get(this.lease.jobId, kind);
    const stage = JSON.parse(row.payload), attempt = this.jobs.attempt(stage);
    this.jobs.update(this.lease, stage, { artifactIds: [...new Set([...attempt.artifactIds, artifact.id])] });
  }
  route(provider, extra = {}) {
    return { providerId: provider?.providerId ?? null, model: provider?.model ?? null,
      apiVersion: provider?.apiVersion ?? null, workflowVersion: 'song-durable-v1', ...extra };
  }
  spool(stage) { const path = join(this.store.directory(this.project), '.executions'); mkdirSync(path, { recursive: true, mode: 0o700 }); return join(path, stage.attemptId); }
  readResult(stage) {
    const path = this.spool(stage);
    if (!existsSync(path)) return null;
    const record = JSON.parse(readFileSync(path, 'utf8'));
    if (record.attemptId !== stage.attemptId || hash(record.result) !== record.sha256) throw new MediaFailure('stored_result_invalid', stage.kind);
    return { value: decode(JSON.parse(record.result)), sha256: record.sha256 };
  }
  persistResult(stage, value) {
    const result = JSON.stringify(encode(value));
    const path = this.spool(stage), temp = `${path}.${this.lease.token}.tmp`;
    durableWrite(temp, JSON.stringify({ attemptId: stage.attemptId, sha256: hash(result), result }));
    this.jobs.fenced(this.lease, () => {
      if (!existsSync(path)) renameSync(temp, path);
    });
    return this.readResult(stage);
  }
  async provider(kind, provider, input, invoke) {
    const stage = this.jobs.stage(this.lease, kind, input, this.route(provider, { decision: this.done('route') }));
    this.activeStage = stage;
    let attempt = this.jobs.attempt(stage);
    const stored = this.readResult(stage);
    if (stored) {
      this.jobs.update(this.lease, stage, { status: 'completed', completedAt: attempt.completedAt ?? this.jobs.timestamp(),
        resultSha256: stored.sha256, uncertainty: null, providerStatus: 'completed', providerMetadata: stored.value?.metadata ?? null,
        externalExecutionId: attempt.externalExecutionId ?? stored.value?.metadata?.responseId ?? null });
      return stored.value;
    }
    if (attempt.status === 'completed') throw new ReviewRequired(kind, 'stored_result_missing');
    if (['uncertain', 'failed'].includes(attempt.status)) throw new ReviewRequired(kind);
    const execution = provider?.durableExecution;
    const canReconcile = execution?.protocol === 'idempotent-submit-lookup-v1';
    if (attempt.status !== 'prepared' && !canReconcile) throw new ReviewRequired(kind);
    await this.hook('before_dispatch', { stage, attempt });
    let result;
    try {
      if (canReconcile) {
        if (!attempt.externalExecutionId) {
          attempt = this.jobs.update(this.lease, stage, { status: 'dispatching', billing: 'unknown', uncertainty: 'acceptance_unknown', startedAt: attempt.startedAt ?? this.jobs.timestamp() });
          const accepted = await execution.submit({ idempotencyKey: attempt.id, input: attempt.inputSnapshot });
          await this.hook('provider_accepted', { stage, accepted });
          if (typeof accepted.id !== 'string' || !accepted.id.length) throw new ReviewRequired(kind);
          attempt = this.jobs.update(this.lease, stage, { status: 'submitted', externalExecutionId: accepted.id, providerStatus: accepted.status, uncertainty: null, billing: accepted.billing ?? 'unknown' });
          await this.hook('execution_persisted', { stage, attempt });
        }
        const external = await execution.lookup(attempt.externalExecutionId);
        this.jobs.update(this.lease, stage, { providerStatus: external.status, billing: external.billing ?? 'unknown' });
        if (external.status === 'pending') throw new PendingExecution();
        if (external.status !== 'completed') throw new MediaFailure('provider_execution_failed', kind);
        result = external.result;
      } else {
        this.jobs.update(this.lease, stage, { status: 'dispatching', billing: 'unknown', uncertainty: 'acceptance_unknown', startedAt: this.jobs.timestamp() });
        result = await invoke(attempt.inputSnapshot);
      }
      const saved = this.persistResult(stage, result);
      await this.hook('result_persisted', { stage });
      this.jobs.update(this.lease, stage, { status: 'completed', completedAt: this.jobs.timestamp(), uncertainty: null,
        externalExecutionId: attempt.externalExecutionId ?? result?.metadata?.responseId ?? null,
        providerStatus: 'completed', providerMetadata: result?.metadata ?? null, resultSha256: saved.sha256 });
      return saved.value;
    } catch (error) {
      if (error instanceof PendingExecution || error instanceof LeaseLost || error?.simulatedCrash) throw error;
      const failure = error instanceof MediaFailure ? error : new ReviewRequired(kind);
      const uncertain = failure instanceof ReviewRequired || /unknown|timeout|transport/.test(failure.code);
      this.jobs.update(this.lease, stage, { status: uncertain ? 'uncertain' : 'failed', uncertainty: uncertain ? 'review_required' : null,
        failure: failure.toJSON(), completedAt: this.jobs.timestamp() });
      throw failure;
    }
  }
  async artifact(kind, fileName, mimeType, input, produce, extra = {}) {
    const stage = this.jobs.stage(this.lease, kind, input, { providerId: 'local', workflowVersion: 'song-durable-v1' });
    this.activeStage = stage;
    const existing = this.jobs.db.prepare('SELECT payload FROM media_artifacts WHERE stage_id=? AND slot=?').get(stage.id, fileName);
    const directory = this.store.directory(this.project), final = join(directory, fileName);
    const receiptPath = join(directory, `.${stage.id}.artifact.json`);
    if (existing) {
      const item = JSON.parse(existing.payload);
      if (!existsSync(final) || hash(readFileSync(final)) !== item.sha256) throw new MediaFailure('stored_artifact_invalid', kind);
      return item;
    }
    let receipt = existsSync(receiptPath) ? JSON.parse(readFileSync(receiptPath, 'utf8')) : null;
    if (!receipt || !existsSync(final) || hash(readFileSync(final)) !== receipt.sha256) {
      if (existsSync(final)) throw new MediaFailure('artifact_publication_conflict', kind);
      const temp = join(directory, `.${stage.id}.${this.lease.token}.${randomUUID()}.${fileName}`);
      this.jobs.update(this.lease, stage, { status: 'running', startedAt: this.jobs.attempt(stage).startedAt ?? this.jobs.timestamp() });
      const details = await produce(temp, this.jobs.attempt(stage).inputSnapshot);
      const bytes = readFileSync(temp);
      if (!bytes.length || bytes.length > 256 * 1024 * 1024) throw new MediaFailure('invalid_artifact_size', kind);
      const fd = openSync(temp, 'r+'); try { fsyncSync(fd); } finally { closeSync(fd); }
      receipt = { ...extra, ...details, id: stage.artifactId, versionId: stage.artifactVersionId, producingStageId: stage.id,
        fileName, mimeType, byteSize: bytes.length, sha256: hash(bytes), sourceArtifactIds: input.sourceArtifactIds ?? [],
        ...(input.sourceAttemptId ? { sourceAttemptId: input.sourceAttemptId, sourceStageId: input.sourceStageId } : {}) };
      const receiptTemp = `${receiptPath}.${this.lease.token}.tmp`;
      durableWrite(receiptTemp, JSON.stringify(receipt));
      // Fencing covers filesystem publication too. Obsolete workers can write only their private temp file.
      this.jobs.fenced(this.lease, () => { renameSync(receiptTemp, receiptPath); renameSync(temp, final); });
      await this.hook('artifact_published', { stage, artifact: receipt });
    }
    this.jobs.fenced(this.lease, () => {
      this.jobs.db.prepare('INSERT OR IGNORE INTO media_artifacts VALUES (?,?,?,?)').run(receipt.id, stage.id, fileName, JSON.stringify(receipt));
      const attempt = this.jobs.attempt(stage);
      Object.assign(attempt, { status: 'completed', completedAt: this.jobs.timestamp(), updatedAt: this.jobs.timestamp(), artifactIds: [receipt.id] });
      this.jobs.db.prepare('UPDATE media_attempts SET payload=? WHERE id=?').run(JSON.stringify(attempt), attempt.id);
    });
    return receipt;
  }
}
