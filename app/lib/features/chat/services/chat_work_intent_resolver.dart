import '../../mission/models/mission_suggestion.dart';
import 'mission_suggestion_service.dart';

sealed class ChatWorkIntentResult {
  const ChatWorkIntentResult(this.resolvedPrompt);

  final String resolvedPrompt;
}

class ChatWorkProceed extends ChatWorkIntentResult {
  const ChatWorkProceed(super.resolvedPrompt);
}

class ChatWorkOrchestrate extends ChatWorkIntentResult {
  const ChatWorkOrchestrate({
    required String resolvedPrompt,
    required this.missionSuggestion,
  }) : super(resolvedPrompt);

  final MissionSuggestion missionSuggestion;
}

enum ChatUnsupportedActionKind { videoEditing, videoCreation }

class ChatWorkUnsupportedAction extends ChatWorkIntentResult {
  const ChatWorkUnsupportedAction({
    required String resolvedPrompt,
    required this.actionKind,
  }) : super(resolvedPrompt);

  final ChatUnsupportedActionKind actionKind;

  String get userMessage {
    switch (actionKind) {
      case ChatUnsupportedActionKind.videoEditing:
        return 'Video editing isn’t connected yet.';
      case ChatUnsupportedActionKind.videoCreation:
        return 'Video creation isn’t connected yet.';
    }
  }
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
    r'\b(?:edit|combine|merge|cut|trim)\b.*\bvideos?\b|\bvideos?\b.*\b(?:edit|combine|merge|cut|trim)\b',
    caseSensitive: false,
  );
  static final RegExp _videoCreation = RegExp(
    r'\b(?:make|create|produce|generate)\s+(?:\w+\s+){0,3}(?:tiktok\s+)?videos?\b',
    caseSensitive: false,
  );
  static final RegExp _textOnlyWorkflow = RegExp(
    r'\b(?:content\s+calendar|article\s+series|blog\s+series|email\s+sequence|newsletter\s+series|social\s+media\s+plan|social\s+media\s+content|content\s+plan)\b',
    caseSensitive: false,
  );

  ChatWorkIntentResult resolve(String prompt) {
    final resolvedPrompt = prompt.trim();

    if (resolvedPrompt.isEmpty ||
        _informationalQuestion.hasMatch(resolvedPrompt)) {
      return ChatWorkProceed(resolvedPrompt);
    }

    if (_videoEditing.hasMatch(resolvedPrompt)) {
      return ChatWorkUnsupportedAction(
        resolvedPrompt: resolvedPrompt,
        actionKind: ChatUnsupportedActionKind.videoEditing,
      );
    }

    if (_videoCreation.hasMatch(resolvedPrompt)) {
      return ChatWorkUnsupportedAction(
        resolvedPrompt: resolvedPrompt,
        actionKind: ChatUnsupportedActionKind.videoCreation,
      );
    }

    final suggestion = _missionSuggestionService.suggestFor(resolvedPrompt);
    if (suggestion != null && _textOnlyWorkflow.hasMatch(resolvedPrompt)) {
      return ChatWorkOrchestrate(
        resolvedPrompt: resolvedPrompt,
        missionSuggestion: suggestion,
      );
    }

    return ChatWorkProceed(resolvedPrompt);
  }
}
