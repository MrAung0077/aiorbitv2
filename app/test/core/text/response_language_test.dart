import 'package:aiorbit/core/text/response_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('responseLanguageFor', () {
    test('serializes only the supported gateway response-language values', () {
      expect(ResponseLanguage.english.wireValue, 'en');
      expect(ResponseLanguage.burmese.wireValue, 'my');
      expect(ResponseLanguage.auto.wireValue, 'auto');
    });

    test('keeps an English prompt in English', () {
      expect(
        responseLanguageFor('Create a Facebook content plan for this week.'),
        ResponseLanguage.english,
      );
      expect(
        responseLanguageInstructionFor(
          'Create a Facebook content plan for this week.',
        ),
        isNot(contains('natural Burmese throughout')),
      );
    });

    test('uses the Burmese writing contract for a Burmese prompt', () {
      const prompt =
          'Facebook နဲ့ TikTok အတွက် တစ်ပတ်စာ Content အစီအစဉ် ပြင်ဆင်ပေးပါ။';

      expect(responseLanguageFor(prompt), ResponseLanguage.burmese);
      final policy = responseLanguageInstructionFor(prompt);
      expect(policy, contains('natural Burmese throughout'));
      expect(policy, contains('Before finalizing'));
      expect(policy, contains('malformed\n  Burmese words'));
      expect(policy, contains('broken Unicode-looking fragments'));
      expect(policy, contains('nonsensical\n  transliterations'));
      expect(policy, contains('simple clear Burmese phrase'));
      expect(
        policy,
        contains('Never invent a\n  Burmese word or transliteration'),
      );
      expect(policy, contains('Facebook, TikTok, YouTube, Content, Hook'));
    });

    test('uses the dominant language for mixed-language prompts', () {
      expect(
        responseLanguageFor(
          'Facebook နဲ့ TikTok အတွက် Content အစီအစဉ်ကို အသုံးဝင်အောင် ပြင်ဆင်ပေးပါ။',
        ),
        ResponseLanguage.burmese,
      );
      expect(
        responseLanguageFor(
          'Create a Facebook Content plan for this week with simple goals. မြန်မာ',
        ),
        ResponseLanguage.english,
      );
    });

    test('honors explicit English and Burmese response requests', () {
      expect(
        responseLanguageFor(
          'Facebook အတွက် Content plan ရေးပေးပါ။ Reply in English.',
        ),
        ResponseLanguage.english,
      );
      expect(
        responseLanguageFor(
          'Create a Facebook content plan for this week. မြန်မာလိုပြောပါ။',
        ),
        ResponseLanguage.burmese,
      );
    });

    test(
      'honors Burmese-language wording that explicitly requests English',
      () {
        expect(
          responseLanguageFor(
            'မြန်မာနိုင်ငံအကြောင်းကို English လို အတိုချုံးပြောပါ',
          ),
          ResponseLanguage.english,
        );
        expect(
          responseLanguageFor('Facebook အကြောင်းကို အင်္ဂလိပ်လို ရှင်းပြပါ'),
          ResponseLanguage.english,
        );
      },
    );

    test('honors explicit Burmese wording in otherwise English prompts', () {
      expect(
        responseLanguageFor('Explain Myanmar history. မြန်မာဘာသာနဲ့ ပြောပါ။'),
        ResponseLanguage.burmese,
      );
    });
  });
}
