enum ResponseLanguage { english, burmese }

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
