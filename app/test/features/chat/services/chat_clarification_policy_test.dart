import 'package:aiorbit/features/chat/models/pending_chat_clarification.dart';
import 'package:aiorbit/features/chat/services/chat_clarification_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = ChatClarificationPolicy();

  group('ChatClarificationPolicy', () {
    test('asks only for a missing Facebook post topic', () {
      final result = policy.resolve(
        prompt: 'Write a Facebook post',
        pendingClarification: null,
      );

      expect(result, isA<ChatClarificationRequest>());
      final request = result as ChatClarificationRequest;
      expect(request.question, 'What should the Facebook post be about?');
      expect(
        request.pendingIntent.intent,
        ChatClarificationIntent.facebookPost,
      );
      expect(request.pendingIntent.requiredField, 'topic');
    });

    test('proceeds when a Facebook post has a topic', () {
      final result = policy.resolve(
        prompt: 'Write a Facebook post about our summer sale',
        pendingClarification: null,
      );

      expect(result, isA<ChatClarificationProceed>());
    });

    test('asks one first question for TikTok work without a topic', () {
      final result = policy.resolve(
        prompt: 'Help me make TikTok videos to get more views and earn money',
        pendingClarification: null,
      );

      expect(result, isA<ChatClarificationRequest>());
      final request = result as ChatClarificationRequest;
      expect(
        request.question,
        'Do you already have a content topic, or should Ovexiq choose one for you?',
      );
      expect(
        request.pendingIntent.intent,
        ChatClarificationIntent.tiktokVideos,
      );
    });

    test('proceeds when TikTok videos have a topic', () {
      final result = policy.resolve(
        prompt: 'Make TikTok videos about easy home cooking',
        pendingClarification: null,
      );

      expect(result, isA<ChatClarificationProceed>());
    });

    test('uses optional Facebook choices as defaults', () {
      final result = policy.resolve(
        prompt: 'Write a Facebook post about our summer sale',
        pendingClarification: null,
      );

      expect(result, isA<ChatClarificationProceed>());
    });

    test('resumes a pending intent without another question', () {
      const pending = PendingChatClarification(
        originalPrompt: 'Write a Facebook post',
        question: 'What should the Facebook post be about?',
        intent: ChatClarificationIntent.facebookPost,
        requiredField: 'topic',
      );

      final result = policy.resolve(
        prompt: 'Our summer sale',
        pendingClarification: pending,
      );

      expect(result, isA<ChatClarificationProceed>());
      expect(
        (result as ChatClarificationProceed).resolvedPrompt,
        contains('Write a Facebook post'),
      );
      expect(result.resolvedPrompt, contains('Our summer sale'));
    });

    test('asks one niche question before a social content-plan Mission', () {
      final result = policy.resolve(
        prompt:
            'Facebook နဲ့ TikTok မှာ fake follower မသုံးဘဲ follower တိုးဖို့ ရက် ၃၀ Content Plan ဖန်တီးပေးပါ။',
        pendingClarification: null,
      );

      expect(result, isA<ChatClarificationRequest>());
      final request = result as ChatClarificationRequest;
      expect(
        request.pendingIntent.intent,
        ChatClarificationIntent.socialContentPlan,
      );
      expect(request.pendingIntent.requiredField, 'contentNiche');
      expect(request.question, contains('Page'));
    });

    test('does not ask again when a social content-plan niche is supplied', () {
      final result = policy.resolve(
        prompt:
            'Create a 30-day Facebook and TikTok content plan for a home-cooking Page.',
        pendingClarification: null,
      );

      expect(result, isA<ChatClarificationProceed>());
    });
  });
}
