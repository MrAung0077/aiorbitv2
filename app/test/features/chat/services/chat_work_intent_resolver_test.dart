import 'package:aiorbit/features/chat/services/chat_work_intent_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = ChatWorkIntentResolver();

  test('lets a supported one-shot text deliverable proceed', () {
    final result = resolver.resolve(
      'Write a Facebook post about our summer sale',
    );

    expect(result, isA<ChatWorkProceed>());
    expect(
      result.resolvedPrompt,
      'Write a Facebook post about our summer sale',
    );
  });

  test('orchestrates only explicit text-only multi-step work', () {
    final result = resolver.resolve(
      'Create a 30-day social media content calendar for a coffee shop',
    );

    expect(result, isA<ChatWorkOrchestrate>());
  });

  test('routes a fully Burmese multi-step creator goal to a Mission', () {
    final result = resolver.resolve(
      'Facebook စာမျက်နှာအတွက် တစ်လစာ အကြောင်းအရာ အစီအစဉ်နဲ့ အရောင်းမြှင့်တင်ရေး စီမံချက် ပြင်ဆင်ပေးပါ။',
    );

    expect(result, isA<ChatWorkOrchestrate>());
    final suggestion = (result as ChatWorkOrchestrate).missionSuggestion;
    expect(suggestion.reason, contains('ဤရည်ရွယ်ချက်'));
  });

  test('keeps a broad research request in normal Chat', () {
    expect(
      resolver.resolve('Research Kaspa smart contracts'),
      isA<ChatWorkProceed>(),
    );
  });

  test('keeps Burmese explanation requests in normal Chat', () {
    expect(
      resolver.resolve('အကြောင်းအရာ အစီအစဉ်ကို ရှင်းပြပေးပါ။'),
      isA<ChatWorkProceed>(),
    );
  });

  test('prepares an honest handoff for actual Burmese video editing', () {
    final result = resolver.resolve(
      'ဒီ video ကို ဖြတ်ပြီး subtitle ထည့်ကာ MP4 export လုပ်ပေးပါ။',
    );

    expect(result, isA<ChatWorkProceed>());
    final handoff = result as ChatWorkProceed;
    expect(handoff.responseGuidance, contains('cannot perform'));
    expect(handoff.responseGuidance, contains('Never claim'));
  });

  test('keeps Burmese Reel hooks as text content, not video execution', () {
    final result = resolver.resolve(
      'Creator growth page အတွက် လူတွေ scroll ရပ်သွားစေမယ့် Reel hook 10 ခုကို တိုက်ရိုက်ရေးပေးပါ။',
    );

    expect(result, isA<ChatWorkProceed>());
    expect((result as ChatWorkProceed).responseGuidance, isNull);
  });

  test('routes a Burmese CapCut package to a text preparation mission', () {
    final result = resolver.resolve(
      'Myanmar small business owners အတွက် 20-second Facebook Reel တစ်ခုလုပ်ချင်တယ်။ CapCut မှာ ချက်ချင်းဆက်လုပ်နိုင်အောင် scene timing, script, on-screen text, asset list, BGM mood နဲ့ export settings ပြင်ပေးပါ။',
    );

    expect(result, isA<ChatWorkOrchestrate>());
    final suggestion = (result as ChatWorkOrchestrate).missionSuggestion;
    expect(suggestion.reason, contains('workflow'));
    expect(suggestion.plannedSteps.join('\n'), contains('CapCut'));
  });

  test('keeps informational video questions on normal text chat', () {
    expect(
      resolver.resolve('How do I edit these 5 videos into one video?'),
      isA<ChatWorkProceed>(),
    );
  });
}
