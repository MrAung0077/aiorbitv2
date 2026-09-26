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

    test('keeps generated Mission plans compact with distinct step scopes', () {
      const prompts = <String>[
        'Create a marketing campaign for our product launch',
        'Write a 10-part article series for new founders',
        'Design a complete brand identity and asset kit',
        'Create a 30-day social media content calendar',
        'Analyze 12 months of revenue data and prepare a report',
      ];

      for (final prompt in prompts) {
        final suggestion = service.suggestFor(prompt);

        expect(suggestion, isNotNull, reason: prompt);
        final scopes = suggestion!.plannedSteps
            .map((step) => step.trim())
            .toList(growable: false);
        expect(scopes, isNotEmpty, reason: prompt);
        expect(scopes.length, lessThanOrEqualTo(5), reason: prompt);
        expect(scopes.toSet(), hasLength(scopes.length), reason: prompt);
      }
    });

    test('keeps Burmese mission explanations and steps in Burmese', () {
      final suggestion = service.suggestFor(
        'Facebook နဲ့ TikTok အတွက် နေ့စဉ် content strategy နဲ့ posting workflow တစ်ခုလုပ်ပေးပါ။',
      );

      expect(suggestion, isNotNull);
      expect(suggestion!.reason, contains('ဤရည်ရွယ်ချက်'));
      expect(suggestion.plannedSteps.join('\n'), contains('ပစ်မှတ်ပရိသတ်'));
      expect(
        suggestion.plannedSteps.join('\n'),
        isNot(contains('Audience နှင့်')),
      );
    });

    test(
      'keeps familiar creator and development terms in natural Burmese plans',
      () {
        final cases = <String>[
          'Facebook နဲ့ TikTok အတွက် တစ်ပတ်စာ Content အစီအစဉ် ပြင်ဆင်ပေးပါ။',
          'CapCut အတွက် scene timing, Script နဲ့ Asset list ပါတဲ့ Reel plan ပြင်ဆင်ပေးပါ။',
          'Canva အသုံးပြုရန် Facebook Post Content အစီအစဉ် ပြင်ဆင်ပေးပါ။',
          'Codex အတွက် app တစ်ခုရဲ့ development plan ပြင်ဆင်ပေးပါ။',
        ];

        for (final prompt in cases) {
          final suggestion = service.suggestFor(prompt);
          expect(suggestion, isNotNull, reason: prompt);
          final visiblePlan = suggestion!.plannedSteps.join('\n');
          expect(visiblePlan, isNot(contains('ရည်အသွား')));
          expect(visiblePlan, isNot(contains('ဒျမိုန့် tips')));
          expect(visiblePlan, isNot(contains('စိတ်တိုချင်းဖျော်ဖြေရေး')));
        }
      },
    );

    test('uses honest preparation wording for a development handoff', () {
      final suggestion = service.suggestFor(
        'Booking app တစ်ခုအတွက် implementation plan နဲ့ Codex handoff ပြင်ပေးပါ။',
      );

      expect(suggestion, isNotNull);
      expect(suggestion!.category, MissionCategory.development);
      expect(
        suggestion.plannedSteps.join('\n'),
        contains('Codex/GitHub အတွက် Handoff package'),
      );
      expect(
        suggestion.plannedSteps.join('\n'),
        isNot(contains('Build the core solution')),
      );
    });
  });
}
