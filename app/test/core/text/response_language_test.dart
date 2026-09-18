import 'package:aiorbit/core/text/response_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('responseLanguageFor', () {
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
      expect(
        responseLanguageInstructionFor(prompt),
        contains('natural Burmese throughout'),
      );
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
  });
}
