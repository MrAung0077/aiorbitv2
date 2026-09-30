import 'package:aiorbit/features/chat/services/cancelled_request_follow_up.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes concise Burmese cancelled-request retries', () {
    for (final followUp in <String>[
      'ပြန်ရေး',
      'ပြန်လုပ်',
      'ထပ်လုပ်',
      'ဆက်လုပ်',
      'ပြန်စ',
      'နောက်တစ်ခါလုပ်',
      'ပြန်ပေး',
    ]) {
      expect(isCancelledRequestRetryFollowUp(followUp), isTrue);
    }
  });

  test('recognizes concise English cancelled-request retries', () {
    for (final followUp in <String>[
      'retry',
      'try again',
      'redo',
      'do it again',
      'continue',
      'resume',
      'restart',
    ]) {
      expect(isCancelledRequestRetryFollowUp(followUp), isTrue);
    }
  });

  test('does not treat detailed follow-up instructions as a retry', () {
    expect(
      isCancelledRequestRetryFollowUp(
        'Continue, but make a new seven-day plan for a different audience.',
      ),
      isFalse,
    );
    expect(
      isCancelledRequestRetryFollowUp(
        'ပြန်လုပ်ပြီး Facebook အတွက် အသစ် ၇ ရက်စာ plan ရေးပေးပါ။',
      ),
      isFalse,
    );
  });
}
