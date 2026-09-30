import '../controllers/mission_controller.dart';
import '../models/mission.dart';
import '../models/mission_suggestion.dart';
import '../models/mission_status.dart';

enum ChatMissionRunOutcome { completed, cancelled, failed }

class ChatMissionRunResult {
  const ChatMissionRunResult({
    this.mission,
    required this.outcome,
    required this.wasCreated,
  });

  final Mission? mission;
  final ChatMissionRunOutcome outcome;
  final bool wasCreated;
}

/// Keeps Chat's Mission orchestration behind a small boundary: Chat requests
/// work, while Mission remains responsible for persistence and execution.
class ChatMissionCoordinator {
  ChatMissionCoordinator({
    required MissionController missionController,
    required Future<void> Function(String missionId) restoreExecutions,
    required Future<Mission> Function(String missionId) runMission,
  }) : _missionController = missionController,
       _restoreExecutions = restoreExecutions,
       _runMission = runMission;

  final MissionController _missionController;
  final Future<void> Function(String missionId) _restoreExecutions;
  final Future<Mission> Function(String missionId) _runMission;
  final Map<String, Future<ChatMissionRunResult>> _activeRuns =
      <String, Future<ChatMissionRunResult>>{};

  Future<ChatMissionRunResult> startOrResume({
    required MissionSuggestion suggestion,
    required String? conversationId,
  }) {
    final normalizedConversationId = conversationId?.trim();
    final runKey = normalizedConversationId?.isNotEmpty == true
        ? normalizedConversationId!
        : 'unlinked:${suggestion.goal.trim()}';
    final activeRun = _activeRuns[runKey];

    if (activeRun != null) {
      return activeRun;
    }

    final run = _startOrResume(
      suggestion: suggestion,
      conversationId: normalizedConversationId,
    );
    _activeRuns[runKey] = run;
    run.whenComplete(() {
      if (identical(_activeRuns[runKey], run)) {
        _activeRuns.remove(runKey);
      }
    });

    return run;
  }

  Future<ChatMissionRunResult> _startOrResume({
    required MissionSuggestion suggestion,
    required String? conversationId,
  }) async {
    Mission? existingMission;

    try {
      existingMission = conversationId == null || conversationId.isEmpty
          ? null
          : await _missionController.getMissionForConversation(conversationId);
      final initialMission =
          existingMission ??
          await _missionController.startMission(
            suggestion,
            conversationId: conversationId,
          );
      final mission = existingMission?.status == MissionStatus.cancelled
          ? await _missionController.resumeMission(missionId: initialMission.id)
          : initialMission;

      // Recovery must happen before a decision to run, so interrupted task
      // state is preserved and normalized by the existing execution layer.
      await _restoreExecutions(mission.id);

      if (mission.taskProgress.isComplete) {
        return ChatMissionRunResult(
          mission: mission,
          outcome: ChatMissionRunOutcome.completed,
          wasCreated: existingMission == null,
        );
      }

      final completedMission = await _runMission(mission.id);

      return ChatMissionRunResult(
        mission: completedMission,
        outcome: completedMission.status == MissionStatus.cancelled
            ? ChatMissionRunOutcome.cancelled
            : completedMission.taskProgress.isComplete
            ? ChatMissionRunOutcome.completed
            : ChatMissionRunOutcome.failed,
        wasCreated: existingMission == null,
      );
    } catch (_) {
      // Chat deliberately presents a safe, non-technical failure state.
      return ChatMissionRunResult(
        mission: existingMission,
        outcome: ChatMissionRunOutcome.failed,
        wasCreated: existingMission == null,
      );
    }
  }
}
