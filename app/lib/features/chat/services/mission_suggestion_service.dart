import '../../mission/models/mission_category.dart';
import '../../mission/models/mission_suggestion.dart';
import '../../../core/text/response_language.dart';

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
    final language = responseLanguageFor(normalizedPrompt);

    return MissionSuggestion(
      title: _buildTitle(normalizedPrompt),
      goal: normalizedPrompt,
      category: category,
      reason: language == ResponseLanguage.burmese
          ? 'ဤရည်ရွယ်ချက်အတွက် ဆက်စပ်လုပ်ဆောင်ရမည့် အဆင့်များရှိသဖြင့် Mission အဖြစ် စီစဉ်ပေးထားပါသည်။'
          : 'This goal requires connected preparation steps and can be completed as a guided workflow.',
      plannedSteps: _buildPlannedSteps(
        category,
        language: language,
        prompt: normalizedLowerCase,
      ),
    );
  }

  bool _looksLikeWorkflow(String prompt) {
    if (_isInformationalOnly(prompt)) {
      return false;
    }

    const strongWorkflowSignals = <String>[
      'content plan',
      'content calendar',
      'content strategy',
      'posting workflow',
      'capcut',
      'scene timing',
      'storyboard',
      'asset list',
      'export settings',
      'content series',
      'editorial plan',
      'editorial calendar',
      'article series',
      'blog series',
      'newsletter series',
      'podcast series',
      'video series',
      'email sequence',
      'drip campaign',
      'marketing plan',
      'marketing campaign',
      'marketing strategy',
      'go-to-market',
      'brand strategy',
      'customer acquisition plan',
      'lead generation campaign',
      'social media plan',
      'social media campaign',
      'business plan',
      'business strategy',
      'launch plan',
      'project plan',
      'action plan',
      'implementation plan',
      'event plan',
      'wedding plan',
      'travel itinerary',
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
      'write a book',
      'write an ebook',
      'create a guide',
      'white paper',
      'case study',
      'design a brand',
      'brand identity',
      'visual identity',
      'brand guidelines',
      'design system',
      'ui redesign',
      'ux redesign',
      'website redesign',
      'app redesign',
      'asset kit',
      'translate a website',
      'translate my website',
      'translate our website',
      'translate an app',
      'translate my app',
      'translate our app',
      'localize',
      'localization',
      'competitive analysis',
      'competitor analysis',
      'market analysis',
      'data analysis',
      'business analysis',
      'gap analysis',
      'risk analysis',
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
      'help me plan',
      'plan my',
      'plan our',
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

    if (_containsAny(prompt, strongWorkflowSignals)) {
      return true;
    }

    const goalSignals = <String>[
      'marketing',
      'advertising',
      'promotion',
      'writing',
      'write',
      'article',
      'blog',
      'newsletter',
      'script',
      'content',
      'social media',
      'design',
      'logo',
      'poster',
      'banner',
      'ui',
      'ux',
      'translate',
      'translation',
      'analyze',
      'analysis',
      'evaluate',
      'planning',
      'plan',
      'organize',
    ];

    if (!_containsAny(prompt, goalSignals)) {
      return false;
    }

    const complexitySignals = <String>[
      'strategy',
      'campaign',
      'calendar',
      'series',
      'multiple',
      'several',
      'batch',
      'end-to-end',
      'from start to finish',
      'phases',
      'stages',
      'milestones',
      'rollout',
      'launch',
      'recommendations',
      'over the next',
      'for the next',
      'for a month',
      'across platforms',
      'across channels',
      'across languages',
      'across regions',
      'across markets',
      'across segments',
      'report and recommendations',
      'draft, review',
      'draft and review',
    ];

    return _containsAny(prompt, complexitySignals) || _hasScaledScope(prompt);
  }

  bool _hasScaledScope(String prompt) {
    final numericScope = RegExp(
      r'\b(?:[2-9]|[1-9]\d+)\s*'
      r'(?:posts?|articles?|emails?|pages?|documents?|files?|languages?|'
      r'videos?|scripts?|campaigns?|assets?|concepts?|variants?|screens?|'
      r'chapters?|weeks?|months?)\b',
    );

    if (numericScope.hasMatch(prompt)) {
      return true;
    }

    const wordScopes = <String>[
      'two posts',
      'three posts',
      'two articles',
      'three articles',
      'two emails',
      'three emails',
      'two languages',
      'three languages',
      'many files',
      'all pages',
      'every page',
    ];

    return _containsAny(prompt, wordScopes);
  }

  bool _isInformationalOnly(String prompt) {
    const informationalStarts = <String>[
      'what is ',
      'what are ',
      'what does ',
      'define ',
      'explain ',
      'tell me about ',
      'give me a definition',
    ];

    if (!informationalStarts.any(prompt.startsWith)) {
      return false;
    }

    const actionSignals = <String>[
      'create ',
      'build ',
      'write ',
      'design ',
      'analyze ',
      'research the ',
      'research latest ',
      'translate ',
      'develop ',
      'organize ',
      'launch ',
      'help me ',
      'for me',
    ];

    return !_containsAny(prompt, actionSignals);
  }

  MissionCategory _detectCategory(String prompt) {
    if (_containsAny(prompt, const <String>[
      'translate',
      'translation',
      'localize',
      'localization',
    ])) {
      return MissionCategory.custom;
    }

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
      'visual identity',
      'brand guidelines',
      'design system',
      'ui',
      'ux',
      'redesign',
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
      'writing',
      'write',
      'ebook',
      'guide',
      'white paper',
      'case study',
      'email sequence',
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

  List<String> _buildPlannedSteps(
    MissionCategory category, {
    required ResponseLanguage language,
    required String prompt,
  }) {
    if (_containsAny(prompt, const <String>[
      'capcut',
      'scene timing',
      'storyboard',
      'asset list',
      'export settings',
    ])) {
      return language == ResponseLanguage.burmese
          ? const <String>[
              'Reel အတွက် ရည်ရွယ်ချက်၊ ကြာချိန်နှင့် ဖော်မတ် သတ်မှတ်ခြင်း',
              'Hook၊ Scene အစီအစဉ်နှင့် Script ပြင်ဆင်ခြင်း',
              'Screen ပေါ်တွင် ပါမည့်စာ၊ လိုအပ်သော Asset များနှင့် BGM အငွေ့အသက် ရွေးချယ်ခြင်း',
              'CapCut တွင် တည်းဖြတ်ရန် အညွှန်းနှင့် Export setting ပြင်ဆင်ခြင်း',
              'အသုံးပြုရန် အဆင်သင့်ဖြစ်သော Handoff package စုစည်းခြင်း',
            ]
          : const <String>[
              'Define the Reel goal, duration, and format',
              'Prepare the hook, scene timing, and script',
              'Prepare on-screen text, asset list, and BGM mood',
              'Prepare CapCut edit instructions and export settings',
              'Assemble the ready-to-use handoff package',
            ];
    }

    if (language == ResponseLanguage.burmese) {
      return _burmesePlannedSteps(category);
    }
    switch (category) {
      case MissionCategory.development:
        return const [
          'Define the implementation requirements and expected outcome',
          'Prepare the technical architecture and structure',
          'Prepare the implementation checklist and acceptance criteria',
          'Prepare the test plan and verification checklist',
          'Prepare the Codex/GitHub handoff package',
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
          'Prepare scheduling recommendations and a review checklist',
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

  List<String> _burmesePlannedSteps(MissionCategory category) {
    switch (category) {
      case MissionCategory.development:
        return const [
          'လိုအပ်ချက်များနှင့် မျှော်မှန်းရလဒ် သတ်မှတ်ခြင်း',
          'နည်းပညာပိုင်း ဖွဲ့စည်းပုံ စီစဉ်ခြင်း',
          'အကောင်အထည်ဖော်ရန် စာရင်းနှင့် လက်ခံစစ်ဆေးမည့် အချက်များ ပြင်ဆင်ခြင်း',
          'စမ်းသပ်ရန် အစီအစဉ်နှင့် စစ်ဆေးစာရင်း ပြင်ဆင်ခြင်း',
          'Codex/GitHub အတွက် Handoff package ပြင်ဆင်ခြင်း',
        ];
      case MissionCategory.socialMedia:
        return const [
          'ပစ်မှတ်ပရိသတ်နှင့် Content ရည်ရွယ်ချက် သတ်မှတ်ခြင်း',
          'အသုံးပြုမည့် Content အမျိုးအစားနှင့် Platform ရွေးချယ်ခြင်း',
          'Content အစီအစဉ် ရေးဆွဲခြင်း',
          'Post၊ Caption နှင့် လိုအပ်သော Asset များ ပြင်ဆင်ခြင်း',
          'တင်မည့်အချိန် အကြံပြုချက်နှင့် ပြန်လည်စစ်ဆေးရန် စာရင်း ပြင်ဆင်ခြင်း',
        ];
      case MissionCategory.contentCreation:
        return const [
          'ခေါင်းစဉ်၊ ပစ်မှတ်ပရိသတ်နှင့် မျှော်မှန်းရလဒ် သတ်မှတ်ခြင်း',
          'အဓိကအကြောင်းအရာများ စုစည်းခြင်း',
          'ပထမမူကြမ်း ရေးသားခြင်း',
          'Content ကို စစ်ဆေးပြီး ပိုကောင်းအောင် ပြင်ဆင်ခြင်း',
          'တင်သွင်းအသုံးပြုရန် အဆင်သင့်ဖြစ်သော မူ ပြင်ဆင်ခြင်း',
        ];
      default:
        return const [
          'ရည်ရွယ်ချက်နှင့် မျှော်မှန်းရလဒ် သတ်မှတ်ခြင်း',
          'လိုအပ်သည့် အချက်အလက်များ စုစည်းခြင်း',
          'အဆင့်လိုက် အစီအစဉ် ရေးဆွဲခြင်း',
          'လိုအပ်သော ရလဒ်များ ပြင်ဆင်ခြင်း',
          'အသုံးပြုရန် အဆင်သင့်ဖြစ်သော ရလဒ် စုစည်းခြင်း',
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
