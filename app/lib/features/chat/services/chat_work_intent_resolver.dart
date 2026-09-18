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
  static final RegExp _videoEditing = RegExp(
    r'\b(?:edit|combine|merge|cut|trim|export|render)\b.*\b(?:video|clip|mp4)s?\b|\b(?:video|clip|mp4)s?\b.*\b(?:edit|combine|merge|cut|trim|export|render)\b|(?:ဒီ\s*)?(?:video|ဗီဒီယို).*(?:ဖြတ်|တည်းဖြတ်|ပေါင်း|ထည့်).*(?:export|MP4|mp4)',
    caseSensitive: false,
  );
  static final RegExp _videoExecution = RegExp(
    r'\b(?:make|create|produce|generate|render|animate)\b.*\b(?:video|reel|tiktok|mp4)s?\b|\b(?:video|reel|tiktok|mp4)s?\b.*\b(?:make|create|produce|generate|render|animate)\b|(?:ဗီဒီယို|Reel).*(?:generate|render|animate|ဖန်တီး).*(?:ပေး|ပါ)',
    caseSensitive: false,
  );
  static final RegExp _textFirstMissionWorkflow = RegExp(
    r'\b(?:content\s+calendar|article\s+series|blog\s+series|email\s+sequence|newsletter\s+series|social\s+media\s+plan|social\s+media\s+content|content\s+plan|posting\s+workflow|capcut|scene\s+timing|storyboard|asset\s+list|export\s+settings)\b|အကြောင်းအရာ\s*အစီအစဉ်|အကြောင်းအရာ\s*စီမံချက်|အရောင်းမြှင့်တင်ရေး\s*စီမံချက်|လမ်းပြမြေပုံ|အဆင့်ဆင့်',
    caseSensitive: false,
  );
  ChatWorkIntentResult resolve(String prompt) {
    final resolvedPrompt = prompt.trim();

    if (resolvedPrompt.isEmpty ||
        _informationalQuestion.hasMatch(resolvedPrompt)) {
      return ChatWorkProceed(resolvedPrompt);
    }

    if (_videoEditing.hasMatch(resolvedPrompt)) {
      return ChatWorkProceed(
        resolvedPrompt,
        responseGuidance: _externalVideoHandoffGuidance,
      );
    }

    if (_videoExecution.hasMatch(resolvedPrompt)) {
      return ChatWorkProceed(
        resolvedPrompt,
        responseGuidance: _externalVideoHandoffGuidance,
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

  static const String _externalVideoHandoffGuidance =
      'The user requested actual video execution, which Ovexiq cannot perform '
      'internally in this beta. Say that limitation briefly and honestly, then '
      'deliver a ready-to-use external-editor package: scene/order guidance, '
      'cut or subtitle instructions when relevant, export settings, and the '
      'next step in a suitable editor. Never claim that a video or MP4 was created.';
}
