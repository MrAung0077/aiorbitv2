/// Deterministic acceptance checks for Burmese Mission task output.
///
/// This is intentionally a narrow safety gate, not a spelling corrector or a
/// text-replacement layer. It blocks only objectively detectable corruption,
/// internal prompt leakage, and English-dominant prose that conflicts with a
/// Burmese task response.
enum BurmeseMissionOutputQualityIssue {
  unexpectedForeignScript,
  excessiveUnnecessaryEnglish,
  internalOrchestrationLeakage,
}

class BurmeseMissionOutputQualityAssessment {
  const BurmeseMissionOutputQualityAssessment(this.issues);

  final Set<BurmeseMissionOutputQualityIssue> issues;

  bool get isAcceptable => issues.isEmpty;
}

class BurmeseMissionOutputQualityGate {
  const BurmeseMissionOutputQualityGate();

  static const Set<String> allowedEnglishTerms = <String>{
    'facebook',
    'tiktok',
    'reel',
    'content',
    'caption',
    'hook',
    'cta',
    'hashtag',
    'capcut',
    'canva',
    'srt',
    'kpi',
  };

  static final RegExp _unexpectedForeignScript = RegExp(
    r'[\u0530-\u058F\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF'
    r'\u0900-\u0D7F\u0E00-\u0FFF\u1100-\u11FF\u2E80-\u2FDF'
    r'\u3040-\u30FF\u3130-\u318F\u31A0-\u31BF\u3400-\u4DBF'
    r'\u4E00-\u9FFF\uAC00-\uD7AF\uFB50-\uFDFF\uFE70-\uFEFF]',
  );
  static final RegExp _latinWord = RegExp(r'[A-Za-z][A-Za-z0-9+/#.-]*');
  static final RegExp _burmeseCharacter = RegExp(r'[\u1000-\u109F]');
  static const List<String> _internalMarkers = <String>[
    'reserved upcoming task scopes',
    'reserved scopes',
    'future task ownership notes',
    'internal future-task ownership',
    'internal orchestration metadata',
    'task ownership',
    'mission decomposition',
    'internal mission',
    'system instructions',
    'system prompt',
    'previous accepted results',
    'do not mention these to the user',
  ];

  BurmeseMissionOutputQualityAssessment assess(
    String output, {
    bool allowUnexpectedForeignScripts = false,
  }) {
    final normalized = output.trim();
    final issues = <BurmeseMissionOutputQualityIssue>{};

    if (!allowUnexpectedForeignScripts &&
        _unexpectedForeignScript.hasMatch(normalized)) {
      issues.add(BurmeseMissionOutputQualityIssue.unexpectedForeignScript);
    }

    final lowerCase = normalized.toLowerCase();
    if (_internalMarkers.any(lowerCase.contains)) {
      issues.add(BurmeseMissionOutputQualityIssue.internalOrchestrationLeakage);
    }

    if (_hasExcessiveUnnecessaryEnglish(normalized)) {
      issues.add(BurmeseMissionOutputQualityIssue.excessiveUnnecessaryEnglish);
    }

    return BurmeseMissionOutputQualityAssessment(issues);
  }

  bool _hasExcessiveUnnecessaryEnglish(String output) {
    final nonEmptyLines = output
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);

    var englishDominantLineCount = 0;
    var totalUnapprovedLatinWords = 0;
    var totalBurmeseCharacters = 0;

    for (final line in nonEmptyLines) {
      final latinWords = _latinWord
          .allMatches(line)
          .map((match) => match.group(0)!.toLowerCase())
          .where((word) => !allowedEnglishTerms.contains(word))
          .toList(growable: false);
      final burmeseCharacters = _burmeseCharacter.allMatches(line).length;

      totalUnapprovedLatinWords += latinWords.length;
      totalBurmeseCharacters += burmeseCharacters;

      if (latinWords.length >= 2 && burmeseCharacters == 0) {
        englishDominantLineCount += 1;
      }
    }

    return englishDominantLineCount >= 2 ||
        (totalUnapprovedLatinWords >= 8 &&
            totalUnapprovedLatinWords * 2 > totalBurmeseCharacters);
  }
}
