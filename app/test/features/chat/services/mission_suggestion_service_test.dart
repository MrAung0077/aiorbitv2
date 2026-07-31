import 'package:aiorbit/features/chat/services/mission_suggestion_service.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = MissionSuggestionService();

  group('MissionSuggestionService', () {
    test('recognizes genuinely multi-step goals', () {
      final cases = <(String, MissionCategory)>[
        (
          'Create a marketing campaign for our product launch',
          MissionCategory.marketing,
        ),
        (
          'Write a 10-part article series for new founders',
          MissionCategory.contentCreation,
        ),
        (
          'Design a complete brand identity and asset kit',
          MissionCategory.design,
        ),
        (
          'Create a 30-day social media content calendar',
          MissionCategory.socialMedia,
        ),
        (
          'Translate our website into three languages and review terminology',
          MissionCategory.custom,
        ),
        (
          'Analyze 12 months of revenue data and prepare a report',
          MissionCategory.business,
        ),
        (
          'Plan my product launch from research to rollout',
          MissionCategory.custom,
        ),
      ];

      for (final (prompt, category) in cases) {
        final suggestion = service.suggestFor(prompt);

        expect(suggestion, isNotNull, reason: prompt);
        expect(suggestion!.category, category, reason: prompt);
      }
    });

    test('does not promote simple one-shot requests to missions', () {
      const prompts = <String>[
        'Write a short thank-you email',
        'Design a simple logo',
        'Translate this sentence to French',
        'Analyze this paragraph',
        'What does marketing mean?',
        'What is a marketing campaign?',
        'Create one Instagram caption',
      ];

      for (final prompt in prompts) {
        expect(service.suggestFor(prompt), isNull, reason: prompt);
      }
    });
  });
}
