// TEST ONLY. Never imported by the production entry point; no network or paid API.
import { DatabaseSync } from 'node:sqlite';
import { randomUUID, createHash } from 'node:crypto';

export class SyntheticMediaProvider {
  constructor(path, { clock = Date.now, delayMs = 1000, bytes = Buffer.alloc(512, 7) } = {}) {
    this.clock = clock; this.delayMs = delayMs; this.bytes = bytes;
    this.db = new DatabaseSync(path);
    this.db.exec(`PRAGMA busy_timeout=5000; PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL;
      CREATE TABLE IF NOT EXISTS executions(id TEXT PRIMARY KEY, request_key TEXT UNIQUE, input_hash TEXT,
        ready_at INTEGER, status TEXT, output TEXT, lookup_count INTEGER DEFAULT 0);`);
    this.durableExecution = { protocol: 'idempotent-submit-lookup-v1', submit: args => this.submit(args), lookup: id => this.lookup(id) };
  }
  get providerId() { return 'synthetic-test-music'; }
  get model() { return 'fixture-v1'; }
  get apiVersion() { return 'test-v1'; }
  get capabilities() { return { customLyrics: true }; }
  supportsLanguage() { return true; }
  async submit({ idempotencyKey, input }) {
    const digest = createHash('sha256').update(JSON.stringify(input)).digest('hex');
    this.db.exec('BEGIN IMMEDIATE');
    try {
      this.db.prepare('INSERT OR IGNORE INTO executions(id,request_key,input_hash,ready_at,status,output) VALUES (?,?,?,?,?,?)')
        .run(randomUUID(), idempotencyKey, digest, this.clock() + this.delayMs, 'pending', this.bytes.toString('base64'));
      const row = this.db.prepare('SELECT * FROM executions WHERE request_key=?').get(idempotencyKey);
      if (row.input_hash !== digest) throw new Error('synthetic_idempotency_conflict');
      this.db.exec('COMMIT');
      return { id: row.id, status: row.status, billing: 'not_applicable' };
    } catch (error) { this.db.exec('ROLLBACK'); throw error; }
  }
  async lookup(id) {
    this.db.prepare("UPDATE executions SET status='completed' WHERE id=? AND ready_at<=? AND status='pending'").run(id, this.clock());
    this.db.prepare('UPDATE executions SET lookup_count=lookup_count+1 WHERE id=?').run(id);
    const row = this.db.prepare('SELECT * FROM executions WHERE id=?').get(id);
    if (!row) throw new Error('synthetic_execution_missing');
    return { status: row.status, billing: 'not_applicable', ...(row.status === 'completed' ? {
      result: { bytes: Buffer.from(row.output, 'base64'), metadata: { provider: this.providerId, model: this.model, responseId: row.id } },
    } : {}) };
  }
  count() { return this.db.prepare('SELECT COUNT(*) AS n FROM executions').get().n; }
  close() { this.db.close(); }
}

export function simulatedCrash() { return Object.assign(new Error('synthetic_process_crash'), { simulatedCrash: true }); }
