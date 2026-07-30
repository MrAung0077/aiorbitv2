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
      plannedSteps: _buildPlannedSteps(category),
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
      'research',
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

  List<String> _buildPlannedSteps(MissionCategory category) {
    switch (category) {
      case MissionCategory.development:
        return const [
          'Clarify requirements and expected outcome',
          'Plan the technical approach and structure',
          'Build the core solution',
          'Test and fix important issues',
          'Prepare the finished result for delivery',
        ];

      case MissionCategory.design:
        return const [
          'Clarify the visual goal and audience',
          'Define the creative direction',
          'Create the initial design concept',
          'Review and refine the design',
          'Prepare the final design assets',
        ];

      case MissionCategory.education:
        return const [
          'Define the learning objective',
          'Organize the topic into clear sections',
          'Create the learning materials',
          'Add practice and review activities',
          'Evaluate progress and improve the plan',
        ];

      case MissionCategory.marketing:
        return const [
          'Define the campaign goal and target audience',
          'Research the market and key message',
          'Plan the campaign content and channels',
          'Prepare the campaign materials',
          'Review performance and improve the campaign',
        ];

      case MissionCategory.socialMedia:
        return const [
          'Define the audience and content objective',
          'Choose the content themes and platforms',
          'Create the content plan',
          'Prepare posts, captions, and supporting assets',
          'Schedule and review content performance',
        ];

      case MissionCategory.contentCreation:
        return const [
          'Define the topic, audience, and desired result',
          'Research and organize the key ideas',
          'Create the first draft',
          'Review and improve the content',
          'Prepare the final publish-ready version',
        ];

      case MissionCategory.business:
        return const [
          'Clarify the business objective',
          'Research the market and current situation',
          'Develop the strategy and action plan',
          'Prepare the required business materials',
          'Review risks, results, and next actions',
        ];

      case MissionCategory.productivity:
        return const [
          'Clarify the desired outcome and priorities',
          'Break the goal into manageable actions',
          'Organize the actions into a practical schedule',
          'Track progress and resolve blockers',
          'Review the system and improve it',
        ];

      case MissionCategory.custom:
        return const [
          'Clarify the goal and expected outcome',
          'Gather the necessary information',
          'Create a step-by-step action plan',
          'Complete and review each planned step',
          'Prepare the final result',
        ];
    }
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
