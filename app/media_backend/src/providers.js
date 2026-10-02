import { MediaFailure, MusicGenerationProvider, musicPrompt, songSpecInstruction, validateSpec } from './contracts.js';

async function boundedJson(response, maxBytes, stage) {
  if (!response.ok) throw new MediaFailure(response.status === 429 ? 'provider_rate_limited' : 'provider_rejected', stage);
  let size = 0;
  const buffers = [];
  for await (const chunk of response.body) {
    size += chunk.length;
    if (size > maxBytes) throw new MediaFailure('provider_response_too_large', stage);
    buffers.push(Buffer.from(chunk));
  }
  try { return JSON.parse(Buffer.concat(buffers).toString('utf8')); }
  catch { throw new MediaFailure('invalid_provider_response', stage); }
}

async function callJson(fetcher, url, key, body, stage, maxBytes, timeout) {
  if (!key) throw new MediaFailure('provider_not_configured', stage);
  try {
    const response = await fetcher(url, {
      method: 'POST', redirect: 'error', signal: AbortSignal.timeout(timeout),
      headers: { 'Content-Type': 'application/json', ...(stage === 'music' ? { 'x-goog-api-key': key } : { Authorization: `Bearer ${key}` }) },
      body: JSON.stringify(body),
    });
    return await boundedJson(response, maxBytes, stage);
  } catch (error) {
    if (error instanceof MediaFailure) throw error;
    // No raw provider error, body, URL query, headers, or credentials escape.
    throw new MediaFailure(error?.name === 'TimeoutError' ? 'provider_timeout_unknown' : 'provider_transport_unknown', stage);
  }
}

export class SongSpecProvider {
  #key;
  constructor({ apiKey, fetcher = fetch, model = 'openai/gpt-6-astra' }) {
    this.#key = apiKey; this.fetcher = fetcher; this.model = model;
  }
  async create(goal, language, artist) {
    const result = await callJson(this.fetcher, 'https://openrouter.ai/api/v1/chat/completions', this.#key, {
      model: this.model, max_tokens: 4096,
      messages: [{ role: 'system', content: songSpecInstruction(language, artist) }, { role: 'user', content: goal }],
      response_format: { type: 'json_object' },
    }, 'song_spec', 128 * 1024, 180000);
    try {
      if (result.choices?.[0]?.finish_reason !== 'stop') throw new Error();
      return validateSpec(JSON.parse(result.choices[0].message.content), language);
    } catch (error) {
      if (error instanceof MediaFailure) throw error;
      throw new MediaFailure('invalid_song_spec', 'song_spec');
    }
  }
}

// Trusted server only. This adapter is never bundled into Flutter.
export class LyriaMusicProvider extends MusicGenerationProvider {
  #key;
  constructor({ apiKey, fetcher = fetch }) { super(); this.#key = apiKey; this.fetcher = fetcher; }
  get providerId() { return 'google-lyria'; }
  get capabilities() { return { languages: ['en', 'my'], customLyrics: true, vocalDirection: true, outputMimeType: 'audio/mpeg', voiceIdentityGuaranteed: false }; }
  async generateSong(spec, artist) {
    if (!this.supportsLanguage(spec.language)) throw new MediaFailure('unsupported_language', 'music', 400);
    const started = Date.now();
    const result = await callJson(this.fetcher,
      'https://generativelanguage.googleapis.com/v1beta/models/lyria-3.5:generateContent', this.#key,
      { contents: [{ role: 'user', parts: [{ text: musicPrompt(spec, artist) }] }] },
      'music', 48 * 1024 * 1024, 300000);
    const candidate = result.candidates?.[0];
    if (candidate?.finishReason !== 'STOP') throw new MediaFailure('music_incomplete_or_blocked', 'music');
    const audioParts = candidate.content?.parts?.filter(part => part.inlineData) ?? [];
    if (audioParts.length !== 1 || !['audio/mpeg', 'audio/mp3'].includes(audioParts[0].inlineData.mimeType)) {
      throw new MediaFailure('invalid_audio_response', 'music');
    }
    const encoded = audioParts[0].inlineData.data;
    if (typeof encoded !== 'string' || !/^[A-Za-z0-9+/]+={0,2}$/.test(encoded)) throw new MediaFailure('invalid_audio_response', 'music');
    const bytes = Buffer.from(encoded, 'base64');
    if (bytes.length < 100 || bytes.length > 32 * 1024 * 1024) throw new MediaFailure('invalid_audio_response', 'music');
    return { bytes, mimeType: 'audio/mpeg', metadata: {
      provider: this.providerId, model: 'lyria-3.5', latencyMs: Date.now() - started,
      finishReason: 'STOP',
      responseId: typeof result.responseId === 'string' && /^[\w-]{1,160}$/.test(result.responseId) ? result.responseId : null,
      totalTokens: Number.isSafeInteger(result.usageMetadata?.totalTokenCount) ? result.usageMetadata.totalTokenCount : null,
    } };
  }
}
