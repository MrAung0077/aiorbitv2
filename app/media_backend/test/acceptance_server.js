// TEST ONLY: interactive synthetic backend for physical Android acceptance.
// No live/paid provider adapter is imported by this entry point.
import { mkdirSync, existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { mediaServer } from '../src/server.js';
import { MediaStore } from '../src/store.js';
import { FfmpegRenderer, runProcess } from '../src/render.js';
import { SongWorkflow } from '../src/workflow.js';
import { SyntheticMediaProvider } from './fixtures/synthetic_media_provider.js';

const SPEC = Object.freeze({
  title: 'Android Acceptance Fixture',
  language: 'en',
  theme: 'durable recovery',
  genre: 'synthetic test',
  mood: 'neutral',
  tempoDirection: 'steady',
  instrumentation: 'synthetic tone',
  vocalCharacteristics: 'synthetic fixture',
  structure: 'verse chorus',
  lyrics: '[Verse 1]\nSynthetic acceptance\n[Chorus]\nSame job, same result',
  chorusStartSeconds: 12,
});

function log(event, data = {}) {
  process.stdout.write(`${JSON.stringify({
    timestamp: new Date().toISOString(),
    event,
    ...data,
  })}\n`);
}

function integerEnv(name, fallback, { min = 0, max = Number.MAX_SAFE_INTEGER } = {}) {
  const raw = process.env[name];
  if (raw == null || raw === '') return fallback;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < min || value > max) {
    throw new Error(`${name} must be an integer between ${min} and ${max}`);
  }
  return value;
}

async function ensureAudioFixtures(root) {
  const directory = join(root, '.acceptance-fixtures');
  mkdirSync(directory, { recursive: true, mode: 0o700 });
  const files = {
    mp3: join(directory, 'primary.mp3'),
    flac: join(directory, 'converted_vocal.flac'),
    ogg: join(directory, 'preview.ogg'),
  };
  const base = [
    '-nostdin', '-v', 'error', '-y',
    '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=44100:duration=48',
  ];
  if (!existsSync(files.mp3)) {
    await runProcess('ffmpeg', [...base, '-c:a', 'libmp3lame', '-b:a', '192k', files.mp3], 120000);
  }
  if (!existsSync(files.flac)) {
    await runProcess('ffmpeg', [...base, '-c:a', 'flac', files.flac], 120000);
  }
  if (!existsSync(files.ogg)) {
    await runProcess('ffmpeg', [...base, '-c:a', 'libopus', '-b:a', '128k', files.ogg], 120000);
  }
  return files;
}

export async function startAcceptanceServer(env = process.env) {
  const root = env.MEDIA_DATA_DIR;
  const serviceKey = env.OVEXIQ_MEDIA_SERVICE_KEY;
  if (!root || !serviceKey || serviceKey.length < 32) {
    throw new Error('Acceptance server requires MEDIA_DATA_DIR and OVEXIQ_MEDIA_SERVICE_KEY (>=32 chars)');
  }

  const port = integerEnv('PORT', 8080, { min: 1, max: 65535 });
  const delayMs = integerEnv('OVEXIQ_SYNTHETIC_DELAY_MS', 120000, {
    min: 1000,
    max: 30 * 60 * 1000,
  });

  const renderer = new FfmpegRenderer();
  await renderer.preflight();
  const fixtureFiles = await ensureAudioFixtures(root);

  const store = new MediaStore(root);
  // Recover durable queued/running work after launcher restart.
  store.interruptUncertain();

  const provider = new SyntheticMediaProvider(join(root, 'synthetic-provider.sqlite'), {
    delayMs,
    artifacts: [
      {
        key: 'primary',
        role: 'combined_mix',
        mimeType: 'audio/mpeg',
        extension: 'mp3',
        format: 'mp3',
        codec: 'mp3',
        bytes: readFileSync(fixtureFiles.mp3),
        technicalMetadata: { synthetic: true, lossless: false },
      },
      {
        key: 'converted_vocal',
        role: 'converted_vocal',
        mimeType: 'audio/flac',
        extension: 'flac',
        format: 'flac',
        codec: 'flac',
        bytes: readFileSync(fixtureFiles.flac),
        technicalMetadata: { synthetic: true, lossless: true, sampleRate: 44100 },
      },
      {
        key: 'preview',
        role: 'preview',
        mimeType: 'audio/ogg',
        extension: 'ogg',
        format: 'ogg',
        codec: 'opus',
        bytes: readFileSync(fixtureFiles.ogg),
        technicalMetadata: { synthetic: true, lossless: false },
      },
    ],
    primaryArtifactKey: 'primary',
  });

  let textCalls = 0;
  const textProvider = {
    providerId: 'synthetic-test-text',
    model: 'fixture-v1',
    apiVersion: 'test-v1',
    capabilities: {},
    async create() {
      textCalls += 1;
      return structuredClone(SPEC);
    },
  };

  const workflow = new SongWorkflow({
    store,
    renderer,
    musicProvider: provider,
    textProvider,
    hook: async (event, details) => {
      const stage = details?.stage;
      const attempt = details?.attempt;
      const artifact = details?.artifact;
      const accepted = details?.accepted;
      log('workflow', {
        point: event,
        projectId: stage?.projectId ?? null,
        jobId: stage?.jobId ?? null,
        stageId: stage?.id ?? null,
        attemptId: stage?.attemptId ?? attempt?.id ?? null,
        stage: stage?.kind ?? null,
        syntheticExecutionId: accepted?.id ?? attempt?.externalExecutionId ?? null,
        artifactId: artifact?.id ?? null,
        artifactSha256: artifact?.sha256 ?? null,
      });
    },
  });

  const server = mediaServer({ store, renderer, serviceKey });
  server.prependListener('request', (req, res) => {
    const startedAt = new Date().toISOString();
    res.once('finish', () => {
      const owner = typeof req.headers['x-ovexiq-account'] === 'string'
        ? req.headers['x-ovexiq-account']
        : null;
      const path = new URL(req.url, 'http://internal').pathname;
      const latest = owner && req.method === 'POST' && path === '/v1/media/projects'
        ? store.list(owner)[0]
        : null;
      log('http', {
        startedAt,
        method: req.method,
        path,
        statusCode: res.statusCode,
        requestId: latest?.requestId ?? null,
        projectId: latest?.projectId ?? null,
      });
    });
  });

  let busy = false;
  const timer = setInterval(async () => {
    if (busy) return;
    busy = true;
    try {
      await workflow.tick();
    } catch (error) {
      log('workflow_error', { code: error?.code ?? error?.name ?? 'unknown' });
    } finally {
      busy = false;
    }
  }, 1000);
  timer.unref();

  const close = async () => {
    clearInterval(timer);
    await new Promise(resolve => server.close(resolve));
    provider.close();
    store.close();
  };

  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, '0.0.0.0', resolve);
  });
  log('acceptance_server_ready', {
    port,
    delayMs,
    mediaDataDir: root,
    provider: provider.providerId,
    paidProviderCallsReachable: false,
    textCalls,
  });

  return { server, store, provider, workflow, close };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const running = await startAcceptanceServer();
  const shutdown = async signal => {
    log('acceptance_server_stopping', { signal });
    await running.close();
    process.exit(0);
  };
  process.once('SIGINT', () => void shutdown('SIGINT'));
  process.once('SIGTERM', () => void shutdown('SIGTERM'));
}
