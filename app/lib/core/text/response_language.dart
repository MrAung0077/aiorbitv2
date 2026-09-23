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
- Keep familiar product and technical names in English when that is clearer:
  Facebook, TikTok, YouTube, Content, Hook, Caption, CTA, Reel, Video, Live,
  CapCut, Canva, Codex, GitHub, KPI, dimensions, and code identifiers.
- When a technical English term needs context, explain it naturally in Burmese
  instead of inventing an obscure Burmese replacement.
- Avoid unnecessary English/Burmese mixing, malformed Myanmar characters,
  corrupted words, repetitive headings, and literal machine-translated prose.
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
