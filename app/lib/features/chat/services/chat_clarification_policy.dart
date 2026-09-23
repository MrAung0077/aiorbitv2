import '../../../core/text/response_language.dart';
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
  static final RegExp _socialContentPlan = RegExp(
    r'(?:facebook|tiktok|fb|page|content).*(?:30\s*(?:day|days)|30-day|content\s+plan|content\s+calendar|follower)|(?:30\s*(?:day|days)|30-day|content\s+plan|content\s+calendar|follower).*(?:facebook|tiktok|fb|page|content)|(?:Facebook|TikTok).*(?:၃၀\s*ရက်|Content\s*Plan|follower)|(?:၃၀\s*ရက်|Content\s*Plan|follower).*(?:Facebook|TikTok)',
    caseSensitive: false,
  );
  static final RegExp _contentNicheSignal = RegExp(
    r'\b(?:about|for|niche|topic)\s+[^.?!]+|\b[a-z][a-z\s]{2,}\s+page\b|(?:အကြောင်းအရာ|နယ်ပယ်|ခေါင်းစဉ်)\s*(?:က|မှာ|ဖြင့်|အတွက်)?\s*[^.?!]{2,}',
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

    if (_socialContentPlan.hasMatch(text) &&
        !_contentNicheSignal.hasMatch(text)) {
      final burmese = responseLanguageFor(text) == ResponseLanguage.burmese;
      return _request(
        prompt: text,
        question: burmese
            ? 'ဘယ်လိုအကြောင်းအရာနဲ့ Page သို့မဟုတ် Content တည်ဆောက်ချင်ပါသလဲ? ဥပမာ — ဖုန်း/App အသုံးပြုနည်း၊ အစားအသောက်၊ ခရီးသွား၊ အလှအပ/Fashion၊ ဟာသ/ဖျော်ဖြေရေး၊ စီးပွားရေး/ရောင်းဝယ်ရေး သို့မဟုတ် ကိုယ်တိုင်ရေးပါ။'
            : 'What Page or content niche should this plan focus on? For example: phone/app tips, food, travel, beauty/fashion, entertainment, business/sales, or your own topic.',
        intent: ChatClarificationIntent.socialContentPlan,
        requiredField: 'contentNiche',
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
