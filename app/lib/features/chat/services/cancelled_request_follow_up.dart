/// Matches only concise, explicit requests to retry a just-stopped request.
/// Longer follow-ups remain ordinary new Chat input.
bool isCancelledRequestRetryFollowUp(String text) {
  final normalized = text
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceFirst(RegExp(r'[.!?။]+$'), '');

  return const <String>{
    'ပြန်ရေး',
    'ပြန်လုပ်',
    'ထပ်လုပ်',
    'ဆက်လုပ်',
    'ပြန်စ',
    'နောက်တစ်ခါလုပ်',
    'ပြန်ပေး',
    'retry',
    'try again',
    'redo',
    'do it again',
    'continue',
    'resume',
    'restart',
  }.contains(normalized);
}
