import '../../mission/models/mission_category.dart';
import '../../mission/models/mission_suggestion.dart';

class MissionSuggestionService {
  const MissionSuggestionService();

  MissionSuggestion? suggestFor(String prompt) {
    final normalizedPrompt = prompt.trim();

    if (normalizedPrompt.isEmpty) {
      return null;
    }

    final normalizedLowerCase = normalizedPrompt.toLowerCase();

    if (!_looksLikeWorkflow(normalizedLowerCase)) {
      return null;
    }

    final category = _detectCategory(normalizedLowerCase);

    return MissionSuggestion(
      title: _buildTitle(normalizedPrompt),
      goal: normalizedPrompt,
      category: category,
      reason:
          'This goal appears to require multiple connected steps and may be '
          'better completed as a guided workflow.',
    );
  }

  bool _looksLikeWorkflow(String prompt) {
    const workflowSignals = <String>[
      'content plan',
      'content calendar',
      'marketing plan',
      'marketing campaign',
      'social media plan',
      'social media campaign',
      'business plan',
      'business strategy',
      'launch plan',
      'project plan',
      'study plan',
      'learning plan',
      'lesson plan',
      'course plan',
      'development plan',
      'app development',
      'website development',
      'build an app',
      'build a website',
      'create an app',
      'create a website',
      'create a campaign',
      'create a course',
      'create a series',
      'design a brand',
      'brand identity',
      'workflow',
      'roadmap',
      'step by step',
      'multiple steps',
      'weekly plan',
      'monthly plan',
      '7-day',
      '7 day',
      '30-day',
      '30 day',
      'automate',
      'organize my',
      'help me launch',
      'help me build',
      'help me create',
      'အဆင့်ဆင့်',
      'အစီအစဉ်',
      'စီမံချက်',
      'လမ်းပြမြေပုံ',
      'တစ်ပတ်စာ',
      'တစ်လစာ',
      '၇ ရက်',
      '၃၀ ရက်',
      'app တစ်ခု',
      'website တစ်ခု',
      'campaign တစ်ခု',
      'သင်တန်းတစ်ခု',
    ];

    return _containsAny(prompt, workflowSignals);
  }

  MissionCategory _detectCategory(String prompt) {
    if (_containsAny(prompt, const <String>[
      'flutter',
      'dart',
      'code',
      'coding',
      'developer',
      'development',
      'software',
      'application',
      'mobile app',
      'web app',
      'website',
      'api',
      'database',
      'github',
      'app တစ်ခု',
      'website တစ်ခု',
      'code ရေး',
    ])) {
      return MissionCategory.development;
    }

    if (_containsAny(prompt, const <String>[
      'logo',
      'design',
      'brand identity',
      'ui',
      'ux',
      'poster',
      'banner',
      'visual',
      'ပုံစံ',
      'ဒီဇိုင်း',
      'လိုဂို',
    ])) {
      return MissionCategory.design;
    }

    if (_containsAny(prompt, const <String>[
      'study',
      'learn',
      'lesson',
      'course',
      'teaching',
      'education',
      'exam',
      'school',
      'student',
      'သင်ခန်းစာ',
      'စာလေ့လာ',
      'သင်တန်း',
      'ကျောင်း',
      'ပညာရေး',
    ])) {
      return MissionCategory.education;
    }

    if (_containsAny(prompt, const <String>[
      'marketing',
      'advertising',
      'advertisement',
      'campaign',
      'sales funnel',
      'customer acquisition',
      'promotion',
      'ကြော်ငြာ',
      'စျေးကွက်',
      'အရောင်းမြှင့်',
    ])) {
      return MissionCategory.marketing;
    }

    if (_containsAny(prompt, const <String>[
      'facebook',
      'instagram',
      'tiktok',
      'youtube',
      'social media',
      'linkedin',
      'post schedule',
      'content calendar',
      'fb post',
      'page content',
      'လူမှုကွန်ရက်',
      'ပို့စ်အစီအစဉ်',
    ])) {
      return MissionCategory.socialMedia;
    }

    if (_containsAny(prompt, const <String>[
      'article',
      'blog',
      'script',
      'video script',
      'content',
      'newsletter',
      'podcast',
      'story',
      'caption',
      'စာမူ',
      'ဆောင်းပါး',
      'ဗီဒီယို script',
      'အကြောင်းအရာ',
    ])) {
      return MissionCategory.contentCreation;
    }

    if (_containsAny(prompt, const <String>[
      'business',
      'startup',
      'company',
      'revenue',
      'business model',
      'pricing',
      'market research',
      'competitor',
      'လုပ်ငန်း',
      'ကုမ္ပဏီ',
      'စီးပွားရေး',
      'ဝင်ငွေ',
      'ပြိုင်ဘက်',
    ])) {
      return MissionCategory.business;
    }

    if (_containsAny(prompt, const <String>[
      'productivity',
      'organize',
      'schedule',
      'routine',
      'time management',
      'task management',
      'weekly plan',
      'monthly plan',
      'အချိန်ဇယား',
      'အလုပ်အစီအစဉ်',
      'စီမံ',
    ])) {
      return MissionCategory.productivity;
    }

    return MissionCategory.custom;
  }

  bool _containsAny(String source, List<String> values) {
    for (final value in values) {
      if (source.contains(value)) {
        return true;
      }
    }

    return false;
  }

  String _buildTitle(String prompt) {
    final singleLinePrompt = prompt.replaceAll(RegExp(r'\s+'), ' ');

    const maximumLength = 60;

    if (singleLinePrompt.length <= maximumLength) {
      return singleLinePrompt;
    }

    return '${singleLinePrompt.substring(0, maximumLength - 3).trimRight()}...';
  }
}
