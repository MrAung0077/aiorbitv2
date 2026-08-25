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
    r'\b(?:create|make|generate|draw)\s+(?:(?:me|an?|the)\s+)*(?:\w+\s+){0,3}(?:image|picture)\b',
    caseSensitive: false,
  );

  // These are clear visual subjects in a direct creation request. This stays
  // deliberately small: it lets people ask for a visual without the words
  // "image" or "picture", while leaving ambiguous "create ..." requests on
  // the normal Chat path.
  static final RegExp _visualCreationVerb = RegExp(
    r'\b(?:create|make|generate|draw)\s+(?:me\s+)?',
    caseSensitive: false,
  );
  static final RegExp _visualSubject = RegExp(
    r'\b(?:sunset|sunrise|landscape|mountain|lake|beach|ocean|scene|city|'
    r'buddha|cat|dog|fox|logo|(?:product\s+)?shot|portrait|illustration|'
    r'artwork|painting|wallpaper|icon|car|flower|forest|skyline)\b',
    caseSensitive: false,
  );
  static final RegExp _nonImageDeliverable = RegExp(
    r'\b(?:facebook\s+post|marketing\s+plan|content\s+calendar|video|'
    r'email|(?:blog\s+)?article|script|(?:midjourney\s+)?prompt)\b',
    caseSensitive: false,
  );

  static final RegExp _informationalQuestion = RegExp(
    r'^\s*(?:how\s+(?:do|can|would|should)\s+(?:i|we)|what\s+(?:is|are)|why\s+is|explain\b|tell\s+me\s+(?:about|how)|can\s+you\s+(?:explain|tell\s+me))',
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

    final explicitImageMatch = _imageCreation.firstMatch(text);

    if (explicitImageMatch != null) {
      return _resolveExplicitImageAction(text, explicitImageMatch);
    }

    return _resolveDirectVisualAction(text);
  }

  ChatActionDispatchResult _resolveExplicitImageAction(
    String text,
    Match match,
  ) {
    final subjectMatch = _subjectPrefix.firstMatch(text.substring(match.end));
    final subject = subjectMatch == null
        ? ''
        : subjectMatch.group(1)!.replaceFirst(RegExp(r'[.!?]+$'), '').trim();

    if (subject.isEmpty) {
      return const ChatActionClarification('What should the image be of?');
    }

    return ChatImageActionRequested(subject: subject);
  }

  ChatActionDispatchResult _resolveDirectVisualAction(String text) {
    if (_nonImageDeliverable.hasMatch(text)) {
      return const ChatActionPassThrough();
    }

    final creationMatch = _visualCreationVerb.firstMatch(text);
    if (creationMatch == null) {
      return const ChatActionPassThrough();
    }

    final subject = text
        .substring(creationMatch.end)
        .replaceFirst(RegExp(r'^\s*(?:an?|the)\s+', caseSensitive: false), '')
        .replaceFirst(RegExp(r'[.!?]+$'), '')
        .trim();

    if (subject.isEmpty || !_visualSubject.hasMatch(subject)) {
      return const ChatActionPassThrough();
    }

    return ChatImageActionRequested(subject: subject);
  }
}
