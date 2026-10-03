import { readFileSync, statSync } from 'node:fs';
import { recordProviderEvidence } from '../src/provider_registry_store.js';

// node tools/provider-registry.js <operator-directory> <profile|evaluation> <record.json>
// Never echo record content, paths or exception messages (may contain secrets).
try {
  const [directory, kind, file, extra] = process.argv.slice(2);
  if (!directory || !file || extra || statSync(file).size > 64 * 1024) throw new Error();
  recordProviderEvidence(directory, kind, JSON.parse(readFileSync(file, 'utf8')));
  console.log('Provider evidence record retained. No provider request was made.');
} catch {
  console.error('Registry entry rejected. Check schema, unique ID, file permissions and operator lock. Do not include credentials.');
  process.exitCode = 1;
}
