enum ResponseLanguage {
  english,
  burmese,
  auto;

  String get wireValue => switch (this) {
    ResponseLanguage.english => 'en',
    ResponseLanguage.burmese => 'my',
    ResponseLanguage.auto => 'auto',
  };
}

/// Shared generation contract for Burmese user-facing prose.
///
/// This is deliberately a writing standard rather than a word-replacement
/// layer. Providers still generate the content, while the app keeps the
/// language, tone, and familiar product terminology consistent across Chat
/// and every Mission task.
const String burmeseResponseWritingPolicy = '''
Language: Respond in natural Burmese throughout. Write every heading, bullet,
explanation, and finished result in clear everyday Burmese.
- Prefer short, readable sentences and natural Myanmar sentence structure;
  never translate English sentence structure word-for-word.
- Preserve the user's meaning. Use polite, neutral language.
- Write Burmese first for ordinary words. Retain only familiar product,
  technical, or workflow terms in English when they improve clarity: Facebook,
  TikTok, Reel, Content, Caption, Hook, CTA, Hashtag, CapCut, Canva, SRT, KPI,
  and other explicitly requested product names or technical identifiers.
- Prefer a clear Burmese equivalent for ordinary phrases such as target
  audience, content theme, posting time, caption idea, call to action, and
  campaign objective rather than mixing English unnecessarily.
- Do not include Korean, Chinese, Japanese, Tamil, or other unexpected scripts
  unless the user explicitly requests them. Avoid malformed Myanmar characters,
  corrupted words, invented transliterations, repetitive headings, and literal
  machine-translated prose.
- Before finalizing, perform a lightweight language-quality check for malformed
  Burmese words, broken Unicode-looking fragments, nonsensical
  transliterations, and awkward phrase construction. Correct them without
  changing the intended meaning or adding new facts.
- If a Burmese term is uncertain, prefer a simple clear Burmese phrase or
  retain the standard English term when it improves clarity. Never invent a
  Burmese word or transliteration.
- Never use the pronouns မင်း, နင်, or ငါ. Do not use 🙏.
''';

/// Chooses the language for generated explanatory prose from the request,
/// rather than from the device locale. This keeps mixed Burmese/English goals
/// readable while allowing technical names such as CapCut to stay unchanged.
ResponseLanguage responseLanguageFor(String input) {
  final text = input.trim();
  if (_explicitEnglishRequest.hasMatch(text)) {
    return ResponseLanguage.english;
  }

  if (_explicitBurmeseRequest.hasMatch(text)) {
    return ResponseLanguage.burmese;
  }

  final burmeseCharacters = _burmeseCharacter.allMatches(text).length;
  final latinCharacters = _latinCharacter.allMatches(text).length;
  // Familiar product names such as Facebook, CapCut, or implementation can
  // contain more Latin characters than the Burmese grammar around them. Treat
  // Burmese as dominant once it represents at least half of the Latin-script
  // content, so those embedded terms do not flip an otherwise Burmese request.
  return burmeseCharacters > 0 && burmeseCharacters * 2 >= latinCharacters
      ? ResponseLanguage.burmese
      : ResponseLanguage.english;
}

final RegExp _explicitEnglishRequest = RegExp(
  r'(?:\b(?:in|respond in|write in|reply in)\s+english\b|english\s*(?:လို|နဲ့|ဖြင့်|နှင့်)|အင်္ဂလိပ်လို|အင်္ဂလိပ်ဘာသာ(?:နဲ့|ဖြင့်|နှင့်)?)',
  caseSensitive: false,
);

final RegExp _explicitBurmeseRequest = RegExp(
  r'မြန်မာလို|မြန်မာဘာသာ(?:ဖြင့်|နဲ့|နှင့်)?|\b(?:in|respond in|write in|reply in)\s+burmese\b',
  caseSensitive: false,
);

final RegExp _burmeseCharacter = RegExp(r'[\u1000-\u109f]');
final RegExp _latinCharacter = RegExp(r'[A-Za-z]');

bool isBurmeseResponse(String input) =>
    responseLanguageFor(input) == ResponseLanguage.burmese;

String responseLanguageInstructionFor(String input) => isBurmeseResponse(input)
    ? burmeseResponseWritingPolicy
    : 'Language: Respond in the user\'s requested language.';
