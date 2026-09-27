import '../../../core/text/response_language.dart';
import '../../mission/models/mission_suggestion.dart';
import 'mission_suggestion_service.dart';

sealed class ChatWorkIntentResult {
  const ChatWorkIntentResult(this.resolvedPrompt);

  final String resolvedPrompt;
}

class ChatWorkProceed extends ChatWorkIntentResult {
  const ChatWorkProceed(super.resolvedPrompt, {this.responseGuidance});

  /// Private instruction for a useful text-first fallback. It is never added
  /// to the user's saved message.
  final String? responseGuidance;
}

/// A request that is clear, but cannot be executed by this text-first beta.
///
/// This is deliberately distinct from a request failure: no network work or
/// provider call is attempted and the Chat UI can present it neutrally.
class ChatWorkUnsupported extends ChatWorkIntentResult {
  const ChatWorkUnsupported({
    required String resolvedPrompt,
    required this.message,
  }) : super(resolvedPrompt);

  final String message;
}

class ChatWorkOrchestrate extends ChatWorkIntentResult {
  const ChatWorkOrchestrate({
    required String resolvedPrompt,
    required this.missionSuggestion,
  }) : super(resolvedPrompt);

  final MissionSuggestion missionSuggestion;
}

/// Routes only work Ovexiq can genuinely deliver today.
///
/// Image actions are intentionally handled before this resolver. Multi-step
/// orchestration is restricted to explicit text artifacts because Mission's
/// current executor produces text, not media, applications, or external work.
class ChatWorkIntentResolver {
  const ChatWorkIntentResolver({
    MissionSuggestionService missionSuggestionService =
        const MissionSuggestionService(),
  }) : _missionSuggestionService = missionSuggestionService;

  final MissionSuggestionService _missionSuggestionService;

  static final RegExp _informationalQuestion = RegExp(
    r'^\s*(?:how\s+(?:do|can|would|should)|what\s+(?:is|are)|can\s+you\s+(?:explain|tell)|explain\b|tell\s+me\s+how)',
    caseSensitive: false,
  );
  static final RegExp _burmeseExplanationRequest = RegExp(r'ရှင်းပြ');
  // A direct media request needs both an artifact and an execution action.
  // This deliberately leaves text preparation (ideas, scripts, captions,
  // shot lists, and plans) on the supported path.
  static final RegExp _mediaArtifact = RegExp(
    r'\b(?:reel|video|clip|mp4)s?\b|(?:ရီလ်|ဗီဒီယို|ကလစ်)',
    caseSensitive: false,
  );
  static final RegExp _englishMediaExecutionAction = RegExp(
    r'\b(?:make|create|produce|generate|render|animate|edit|combine|merge|cut|trim|export)\b',
    caseSensitive: false,
  );
  static final RegExp _burmeseMediaExecutionAction = RegExp(
    r'(?:ဖန်တီး|ထုတ်လုပ်|ထုတ်|တည်းဖြတ်|ဖြတ်|ပေါင်း|လုပ်)',
  );
  static final RegExp _burmeseDirectRequestEnding = RegExp(
    r'(?:ပေး\s*)?ပါ[။!]*\s*$',
  );
  static final RegExp _burmeseFutureIntent = RegExp(
    r'(?:လုပ်|ဖန်တီး|ထုတ်).{0,12}(?:ချင်|စိတ်ကူး|စီစဉ်)',
  );
  static final RegExp _publishingExecution = RegExp(
    r'\b(?:publish|upload|schedule)\b.*\b(?:to|on)\b.*\b(?:facebook|instagram|tiktok|youtube)\b|\b(?:facebook|instagram|tiktok|youtube)\b.*\b(?:publish|upload|schedule)\b|\bpost\s+(?:this|it|the\s+(?:content|caption|reel|video))\s+(?:to|on)\s+(?:facebook|instagram|tiktok|youtube)\b|(?:Facebook|Instagram|TikTok|YouTube).{0,50}(?:တင်|upload|publish)\s*(?:လုပ်\s*)?(?:ပေး\s*)?ပါ',
    caseSensitive: false,
  );
  static final RegExp _textFirstMissionWorkflow = RegExp(
    r'\b(?:content\s+calendar|article\s+series|blog\s+series|email\s+sequence|newsletter\s+series|social\s+media\s+plan|social\s+media\s+content|content\s+plan|posting\s+workflow|capcut|scene\s+timing|storyboard|asset\s+list|export\s+settings)\b|အကြောင်းအရာ\s*အစီအစဉ်|အကြောင်းအရာ\s*စီမံချက်|အရောင်းမြှင့်တင်ရေး\s*စီမံချက်|လမ်းပြမြေပုံ|အဆင့်ဆင့်',
    caseSensitive: false,
  );
  ChatWorkIntentResult resolve(String prompt) {
    final resolvedPrompt = prompt.trim();

    if (resolvedPrompt.isEmpty ||
        _informationalQuestion.hasMatch(resolvedPrompt) ||
        _burmeseExplanationRequest.hasMatch(resolvedPrompt)) {
      return ChatWorkProceed(resolvedPrompt);
    }

    if (_isDirectMediaExecution(resolvedPrompt) ||
        _publishingExecution.hasMatch(resolvedPrompt)) {
      return ChatWorkUnsupported(
        resolvedPrompt: resolvedPrompt,
        message: _unsupportedCapabilityMessage(resolvedPrompt),
      );
    }

    final suggestion = _missionSuggestionService.suggestFor(resolvedPrompt);
    // The suggestion service rejects ordinary questions and one-shot
    // deliverables. This further keeps broad topics such as research in
    // normal Chat unless the user asked for a concrete text-first workflow.
    // The workflow signals intentionally cover both English and Burmese.
    if (suggestion != null &&
        _textFirstMissionWorkflow.hasMatch(resolvedPrompt)) {
      return ChatWorkOrchestrate(
        resolvedPrompt: resolvedPrompt,
        missionSuggestion: suggestion,
      );
    }

    return ChatWorkProceed(resolvedPrompt);
  }

  static bool _isDirectMediaExecution(String prompt) {
    if (!_mediaArtifact.hasMatch(prompt)) {
      return false;
    }

    // A future intention can mention technical execution terms such as
    // \"export settings\" while asking only for a text preparation package.
    if (_burmeseFutureIntent.hasMatch(prompt)) {
      return false;
    }

    // English actions are unambiguous even in a mixed-language request.
    if (_englishMediaExecutionAction.hasMatch(prompt)) {
      return true;
    }

    // Burmese "လုပ်" can describe a future text workflow (for example,
    // "Reel တစ်ခုလုပ်ချင်တယ်"). Only treat it as direct execution when the
    // user has made a completed direct request such as "ထုတ်ပေးပါ".
    return _burmeseMediaExecutionAction.hasMatch(prompt) &&
        _burmeseDirectRequestEnding.hasMatch(prompt);
  }

  static String _unsupportedCapabilityMessage(String prompt) {
    return responseLanguageFor(prompt) == ResponseLanguage.burmese
        ? _burmeseUnsupportedCapabilityMessage
        : _englishUnsupportedCapabilityMessage;
  }

  static const String _burmeseUnsupportedCapabilityMessage =
      'ဒီ feature ကို လက်ရှိ Ovexiq beta မှာ မရသေးပါ။\n\n'
      'Reel / video creation features တွေ မကြာခင် ထည့်သွင်းသွားမယ်။\n\n'
      'အခုတော့ script, caption, shot list နဲ့ content plan ကို ပြင်ဆင်ပေးနိုင်ပါတယ်။';

  static const String _englishUnsupportedCapabilityMessage =
      'This feature isn’t available in the current Ovexiq beta yet.\n\n'
      'Reel and video creation features are coming soon.\n\n'
      'For now, Ovexiq can help with the script, caption, shot list, and '
      'content plan.';
}
