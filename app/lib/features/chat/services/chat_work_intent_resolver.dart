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
  static final RegExp _videoEditing = RegExp(
    r'\b(?:edit|combine|merge|cut|trim|export|render)\b.*\b(?:video|clip|mp4)s?\b|\b(?:video|clip|mp4)s?\b.*\b(?:edit|combine|merge|cut|trim|export|render)\b|(?:ဒီ\s*)?(?:video|ဗီဒီယို).*(?:ဖြတ်|တည်းဖြတ်|ပေါင်း|ထည့်).*(?:export|MP4|mp4)',
    caseSensitive: false,
  );
  static final RegExp _videoExecution = RegExp(
    r'\b(?:make|create|produce|generate|render|animate)\b.*\b(?:video|reel|tiktok|mp4)s?\b|\b(?:video|reel|tiktok|mp4)s?\b.*\b(?:make|create|produce|generate|render|animate)\b|(?:ဗီဒီယို|Reel).*(?:generate|render|animate|ဖန်တီး).*(?:ပေး|ပါ)',
    caseSensitive: false,
  );
  // Keep a compact Burmese direct-action shape separate from text planning.
  // For example, this catches "Reel တစ်ခု ဖန်တီးပေးပါ" while leaving
  // "Reel idea ပေးပါ" and "Reel script ရေးပေး" on the supported text path.
  static final RegExp _burmeseDirectVideoCreation = RegExp(
    r'(?:reel|video|ဗီဒီယို)\s*(?:တစ်ခု|တခု)?\s*(?:ကို)?\s*'
    r'(?:ဖန်တီး|လုပ်|ထုတ်လုပ်)\s*(?:ပေး\s*)?ပါ',
    caseSensitive: false,
  );
  static final RegExp _publishingExecution = RegExp(
    r'\b(?:publish|upload|schedule)\b.*\b(?:to|on)\b.*\b(?:facebook|instagram|tiktok|youtube)\b|\b(?:facebook|instagram|tiktok|youtube)\b.*\b(?:publish|upload|schedule)\b|(?:Facebook|Instagram|TikTok|YouTube).{0,50}(?:တင်ပေးပါ|upload\s*လုပ်ပေးပါ|publish\s*လုပ်ပေးပါ)',
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

    if (_videoEditing.hasMatch(resolvedPrompt) ||
        _videoExecution.hasMatch(resolvedPrompt) ||
        _burmeseDirectVideoCreation.hasMatch(resolvedPrompt) ||
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
