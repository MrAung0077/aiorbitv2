enum ResponseLanguage { english, burmese }

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
  if (RegExp(
    r'\b(?:in|respond in|write in)\s+english\b',
    caseSensitive: false,
  ).hasMatch(text)) {
    return ResponseLanguage.english;
  }

  final burmeseCharacters = RegExp(r'[\u1000-\u109f]').allMatches(text).length;
  return burmeseCharacters >= 4
      ? ResponseLanguage.burmese
      : ResponseLanguage.english;
}

bool isBurmeseResponse(String input) =>
    responseLanguageFor(input) == ResponseLanguage.burmese;

String responseLanguageInstructionFor(String input) => isBurmeseResponse(input)
    ? burmeseResponseWritingPolicy
    : 'Language: Respond in the user\'s requested language.';
