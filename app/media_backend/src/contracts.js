export class MediaFailure extends Error {
  constructor(code, stage, status = 503) {
    super(code);
    this.code = code;
    this.stage = stage;
    this.status = status;
  }
  toJSON() { return { code: this.code, stage: this.stage }; }
}

export function requireValue(condition, code = 'invalid_request', stage = 'validation') {
  if (!condition) throw new MediaFailure(code, stage, 400);
}

export const defaultArtist = Object.freeze({
  artistId: 'artist-v1', artistName: 'Ari', gender: 'male',
  vocalProfile: 'Original adult male singer; warm mid-low baritone, lightly textured timbre, restrained verse delivery, open resonant chorus, moderate energy, comfortable middle range. No imitation of any real singer.',
  genreFamily: 'soft rock', visualReferenceIds: [], preferredLanguages: ['en', 'my'],
});

export class MusicGenerationProvider {
  get providerId() { throw new Error('abstract'); }
  get capabilities() { throw new Error('abstract'); }
  supportsLanguage(language) { return this.capabilities.languages.includes(language); }
  async generateSong(_spec, _artist, _requirement) { throw new Error('abstract'); }
}

export function validateSpec(value, language, userFinalLyrics = null) {
  requireValue(value && typeof value === 'object', 'invalid_song_spec', 'song_spec');
  const fields = ['title', 'theme', 'genre', 'mood', 'tempoDirection', 'instrumentation', 'vocalCharacteristics', 'structure', 'lyrics'];
  if (userFinalLyrics !== null) value = { ...value, lyrics: userFinalLyrics };
  for (const key of fields) {
    requireValue(typeof value[key] === 'string' && value[key].trim().length > 0 && value[key].length <= (key === 'lyrics' ? 10000 : 1500), 'invalid_song_spec', 'song_spec');
  }
  if (userFinalLyrics === null) requireValue(/\[Verse(?: 1)?\]/i.test(value.lyrics) && /\[Chorus\]/i.test(value.lyrics), 'invalid_song_structure', 'song_spec');
  requireValue(language !== 'my' || /[\u1000-\u109f]/.test(value.lyrics), 'invalid_lyric_language', 'song_spec');
  requireValue(Number.isFinite(value.chorusStartSeconds) && value.chorusStartSeconds >= 0 && value.chorusStartSeconds <= 180, 'invalid_chorus_time', 'song_spec');
  // Copy only approved fields; never persist arbitrary provider response objects.
  return Object.fromEntries([...fields.map(key => [key, key === 'lyrics' && userFinalLyrics !== null ? userFinalLyrics : value[key].trim()]), ['language', language], ['chorusStartSeconds', value.chorusStartSeconds]]);
}

export function musicPrompt(spec, artist) {
  return [
    'Create one complete original song, approximately 2–3 minutes, with a resolved ending. No artist imitation or copyrighted lyrics.',
    `Sing only in ${spec.language === 'my' ? 'Burmese (Myanmar)' : 'English'}. Use the supplied lyrics exactly.`,
    `Title: ${spec.title}. Theme: ${spec.theme}. Genre: ${spec.genre}. Mood: ${spec.mood}. Tempo: ${spec.tempoDirection}.`,
    `Instrumentation: ${spec.instrumentation}. Structure: ${spec.structure}.`,
    `Stable fictional singer: ${artist.vocalProfile}. Delivery: ${spec.vocalCharacteristics}.`,
    `Aim to begin the main chorus around ${spec.chorusStartSeconds} seconds.`,
    `Lyrics:\n${spec.lyrics}`,
  ].join('\n');
}

export function songSpecInstruction(language, artist) {
  return `Write an original song specification as JSON only. Never copy existing lyrics or imitate a named artist, living or deceased; translate any named-artist request into broad genre/instrument attributes without carrying the name into the result.
Fields (strings): title, theme, genre, mood, tempoDirection, instrumentation, vocalCharacteristics, structure, lyrics. Add numeric chorusStartSeconds (suggested timing, 0–180).
Write a complete 2–3 minute song with [Verse 1], [Chorus], [Verse 2], [Chorus], [Bridge], [Chorus], [Outro]. Title and lyrics language: ${language === 'my' ? 'Burmese' : 'English'}.
${language === 'my' ? 'Use natural, idiomatic, singable Burmese with short melodic phrases, coherent verse/chorus meaning, no literal English translation, garbled Unicode, invented transliterations or foreign-script fragments. Check lyric flow before finalizing.' : 'Use natural English lyrics with concrete imagery, one coherent theme and a strong repeatable chorus. Avoid generic AI filler and forced rhymes.'}
Stable fictional artist vocal profile: ${artist.vocalProfile}
Do not include websites, handoff instructions, or technical provider names. Complete only the song specification.`;
}
