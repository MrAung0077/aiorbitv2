// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Burmese (`my`).
class AppLocalizationsMy extends AppLocalizations {
  AppLocalizationsMy([String locale = 'my']) : super(locale);

  @override
  String get appName => 'Ovexiq';

  @override
  String get appTagline => 'Prompt တစ်ခု။ အကောင်းဆုံး AI။ အကောင်းဆုံးရလဒ်။';

  @override
  String get welcomeTitle => 'Ovexiq မှ ကြိုဆိုပါတယ်';

  @override
  String get welcomeSubtitle =>
      'အလုပ်တိုင်းအတွက် သင့်ရဲ့ ဉာဏ်ရည်မြင့် Workspace';

  @override
  String get getStarted => 'စတင်မယ်';

  @override
  String get continueButton => 'ဆက်သွားမယ်';

  @override
  String get backButton => 'နောက်သို့';

  @override
  String get nextButton => 'ရှေ့သို့';

  @override
  String get doneButton => 'ပြီးပါပြီ';

  @override
  String get cancelButton => 'မလုပ်တော့ပါ';

  @override
  String get saveButton => 'သိမ်းမယ်';

  @override
  String get deleteButton => 'ဖျက်မယ်';

  @override
  String get retryButton => 'ထပ်ကြိုးစားမယ်';

  @override
  String get home => 'ပင်မ';

  @override
  String get chat => 'စကားပြော';

  @override
  String get coach => 'အကြံပေး';

  @override
  String get missions => 'ရည်မှန်းချက်များ';

  @override
  String get history => 'မှတ်တမ်း';

  @override
  String get settings => 'ဆက်တင်များ';

  @override
  String get aiChat => 'AI နှင့် စကားပြောမယ်';

  @override
  String get newChat => 'စကားဝိုင်းအသစ်';

  @override
  String get askAIOrbit => 'Ovexiq ကို မေးပါ...';

  @override
  String get startConversation => 'စကားဝိုင်းအသစ် စတင်ပါ။';

  @override
  String get aiThinking => 'Ovexiq စဉ်းစားနေပါတယ်...';

  @override
  String get copiedToClipboard => 'Clipboard သို့ ကူးယူပြီးပါပြီ';

  @override
  String get somethingWentWrong => 'တစ်ခုခုမှားယွင်းသွားပါတယ်။ ထပ်ကြိုးစားပါ။';

  @override
  String get resultPackReady => 'ရလဒ်အစုံ အဆင်သင့်ဖြစ်ပါပြီ';

  @override
  String get resultPackOneOutput => 'ရလဒ် ၁ ခု အဆင်သင့်ဖြစ်ပါပြီ။';

  @override
  String resultPackOutputCount(int count) {
    return 'ရလဒ် $count ခု အဆင်သင့်ဖြစ်ပါပြီ။';
  }

  @override
  String get completedOutputs => 'ပြီးစီးထားသော ရလဒ်များ';

  @override
  String get completedOneOutput => 'ပြီးစီးထားသော ရလဒ် ၁ ခု';

  @override
  String completedOutputCount(int count) {
    return 'ပြီးစီးထားသော ရလဒ် $count ခု';
  }

  @override
  String get copy => 'ကူးယူမည်';

  @override
  String get copyAllOutputs => 'ရလဒ်အားလုံး ကူးယူမည်';

  @override
  String get language => 'ဘာသာစကား';

  @override
  String get systemLanguage => 'စက်၏ ဘာသာစကား';

  @override
  String get english => 'အင်္ဂလိပ်';

  @override
  String get myanmar => 'မြန်မာ';

  @override
  String get comingSoon => 'မကြာမီ ရရှိပါမည်';

  @override
  String get missionComingSoon => 'Mission စနစ်ကို မကြာမီ ရရှိပါမည်။';

  @override
  String get historyComingSoon =>
      'Chat နှင့် AI အသုံးပြုမှုမှတ်တမ်းကို မကြာမီ ရရှိပါမည်။';
}
