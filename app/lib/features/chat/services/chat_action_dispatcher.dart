sealed class ChatActionDispatchResult {
  const ChatActionDispatchResult();
}

class ChatActionPassThrough extends ChatActionDispatchResult {
  const ChatActionPassThrough();
}

class ChatActionClarification extends ChatActionDispatchResult {
  const ChatActionClarification(this.message);

  final String message;
}

/// A provider-neutral action request that will be fulfilled by a later
/// capability integration.
class ChatImageActionRequested extends ChatActionDispatchResult {
  const ChatImageActionRequested({required this.subject});

  final String subject;
}

/// Detects explicit, executable Chat actions before they reach text AI.
class ChatActionDispatcher {
  const ChatActionDispatcher();

  static final RegExp _imageCreation = RegExp(
    r'\b(?:create|make|generate|draw)\s+(?:an?\s+|the\s+)?(?:image|picture)\b',
    caseSensitive: false,
  );

  static final RegExp _informationalQuestion = RegExp(
    r'^\s*(?:how\s+(?:do|can|would|should)\s+(?:i|we)|what\s+(?:is|are)|why\s+is|explain\b|tell\s+me\s+(?:about|how))',
    caseSensitive: false,
  );

  static final RegExp _subjectPrefix = RegExp(
    r'^\s*(?:of|for|showing|depicting)\s+(.+?)\s*$',
    caseSensitive: false,
  );

  ChatActionDispatchResult dispatch(String prompt) {
    final text = prompt.trim();

    if (text.isEmpty || _informationalQuestion.hasMatch(text)) {
      return const ChatActionPassThrough();
    }

    final match = _imageCreation.firstMatch(text);

    if (match == null) {
      return const ChatActionPassThrough();
    }

    final subjectMatch = _subjectPrefix.firstMatch(text.substring(match.end));
    final subject = subjectMatch == null
        ? ''
        : subjectMatch.group(1)!.replaceFirst(RegExp(r'[.!?]+$'), '').trim();

    if (subject.isEmpty) {
      return const ChatActionClarification('What should the image be of?');
    }

    return ChatImageActionRequested(subject: subject);
  }
}
