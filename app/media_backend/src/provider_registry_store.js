import { appendFileSync, closeSync, existsSync, mkdirSync, openSync, readFileSync, statSync, unlinkSync } from 'node:fs';
import { join } from 'node:path';
import { capabilityProfile, providerEvaluation } from './provider_evaluation_registry.js';

const validators = { profile: capabilityProfile, evaluation: providerEvaluation };
// Operator-only local storage, not an HTTP route or project database migration.
// Append-only records with unique IDs; retire by recording a new dated inactive
// profile/evaluation, never rewriting a historical decision snapshot.
export function readProviderRegistry(directory) {
  const read = kind => {
    const file = join(directory, `${kind}s.jsonl`);
    if (!existsSync(file)) return [];
    if (statSync(file).size > 8 * 1024 * 1024) throw new Error('registry_size_limit');
    return readFileSync(file, 'utf8').split('\n').filter(line => line.trim()).map(line => validators[kind](JSON.parse(line)));
  };
  return { profiles: read('profile'), evaluations: read('evaluation') };
}

export function recordProviderEvidence(directory, kind, value) {
  if (!Object.hasOwn(validators, kind)) throw new Error('invalid_registry_kind');
  const record = validators[kind](value);
  mkdirSync(directory, { recursive: true, mode: 0o700 });
  const lockPath = join(directory, '.entry.lock');
  const lock = openSync(lockPath, 'wx', 0o600); // Fail, do not retry concurrent entry.
  try {
    const registry = readProviderRegistry(directory);
    const records = kind === 'profile' ? registry.profiles : registry.evaluations;
    const key = kind === 'profile' ? 'profileId' : 'evaluationId';
    if (records.some(r => r[key] === record[key])) throw new Error('duplicate_registry_id');
    appendFileSync(join(directory, `${kind}s.jsonl`), `${JSON.stringify(record)}\n`, { encoding: 'utf8', mode: 0o600 });
  } finally { closeSync(lock); unlinkSync(lockPath); }
}
