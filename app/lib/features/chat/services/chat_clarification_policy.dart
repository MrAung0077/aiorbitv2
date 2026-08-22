import '../models/pending_chat_clarification.dart';

sealed class ChatClarificationResult {
  const ChatClarificationResult();
}

class ChatClarificationProceed extends ChatClarificationResult {
  const ChatClarificationProceed(this.resolvedPrompt);

  final String resolvedPrompt;
}

class ChatClarificationRequest extends ChatClarificationResult {
  const ChatClarificationRequest({
    required this.question,
    required this.pendingIntent,
  });

  final String question;
  final PendingChatClarification pendingIntent;
}

/// Identifies only high-confidence, materially required information before an
/// ordinary Chat request reaches an AI provider.
class ChatClarificationPolicy {
  const ChatClarificationPolicy();

  static final RegExp _facebookPost = RegExp(
    r'\b(?:write|create|make|draft)\s+(?:a\s+)?facebook\s+post\b',
    caseSensitive: false,
  );
  static final RegExp _tiktokWork = RegExp(
    r'\b(?:help\s+me\s+)?(?:make|create|plan|produce)\s+(?:\w+\s+){0,3}tiktok\s+videos?\b',
    caseSensitive: false,
  );
  static final RegExp _topicAfterTikTok = RegExp(
    r'\btiktok\s+videos?\s+(?:about|on)\s+.+',
    caseSensitive: false,
  );

  ChatClarificationResult resolve({
    required String prompt,
    PendingChatClarification? pendingClarification,
  }) {
    final text = prompt.trim();

    if (pendingClarification != null) {
      return ChatClarificationProceed(
        '${pendingClarification.originalPrompt}\n\n'
        'User clarification: $text',
      );
    }

    final facebookMatch = _facebookPost.firstMatch(text);

    if (facebookMatch != null && _hasNoDetailsAfter(text, facebookMatch.end)) {
      return _request(
        prompt: text,
        question: 'What should the Facebook post be about?',
        intent: ChatClarificationIntent.facebookPost,
        requiredField: 'topic',
      );
    }

    if (_tiktokWork.hasMatch(text) && !_topicAfterTikTok.hasMatch(text)) {
      return _request(
        prompt: text,
        question:
            'Do you already have a content topic, or should Ovexiq choose one for you?',
        intent: ChatClarificationIntent.tiktokVideos,
        requiredField: 'topicOrTopicSelection',
      );
    }

    return ChatClarificationProceed(text);
  }

  ChatClarificationRequest _request({
    required String prompt,
    required String question,
    required ChatClarificationIntent intent,
    required String requiredField,
  }) {
    return ChatClarificationRequest(
      question: question,
      pendingIntent: PendingChatClarification(
        originalPrompt: prompt,
        question: question,
        intent: intent,
        requiredField: requiredField,
      ),
    );
  }

  bool _hasNoDetailsAfter(String text, int start) {
    return text.substring(start).replaceAll(RegExp(r'[\s.!?]+'), '').isEmpty;
  }
}
