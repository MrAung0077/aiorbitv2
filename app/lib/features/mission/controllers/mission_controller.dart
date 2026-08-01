import '../models/mission.dart';
import '../models/mission_suggestion.dart';
import '../models/mission_task.dart';
import '../models/task_status.dart';
import '../services/mission_factory.dart';
import '../services/mission_repository.dart';

class MissionController {
  MissionController({
    required MissionRepository repository,
    MissionFactory? factory,
  }) : _repository = repository,
       _factory = factory ?? const MissionFactory();

  final MissionRepository _repository;
  final MissionFactory _factory;

  Future<Mission> startMission(
    MissionSuggestion suggestion, {
    String? conversationId,
  }) async {
    final mission = _factory.createFromSuggestion(
      suggestion: suggestion,
      conversationId: conversationId,
    );

    await _repository.saveMission(mission);

    return mission;
  }

  Future<List<Mission>> getMissions() {
    return _repository.getAllMissions();
  }

  Future<Mission?> getMission(String id) {
    return _repository.getMission(id);
  }

  Future<Mission?> getMissionForConversation(String conversationId) async {
    final normalizedId = conversationId.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    final missions = await _repository.getAllMissions();
    Mission? latestMission;

    for (final mission in missions) {
      if (mission.conversationId != normalizedId) {
        continue;
      }

      if (latestMission == null ||
          mission.updatedAt.isAfter(latestMission.updatedAt)) {
        latestMission = mission;
      }
    }

    return latestMission;
  }

  bool canTransitionTaskStatus(TaskStatus from, TaskStatus to) {
    return switch (from) {
      TaskStatus.pending => to == TaskStatus.inProgress,
      TaskStatus.inProgress => to == TaskStatus.completed,
      TaskStatus.completed => to == TaskStatus.inProgress,
      TaskStatus.skipped || TaskStatus.failed => false,
    };
  }

  Future<Mission> updateTaskStatus({
    required String missionId,
    required String taskId,
    required TaskStatus status,
  }) async {
    final mission = await _repository.getMission(missionId);

    if (mission == null) {
      throw StateError('Mission "$missionId" was not found.');
    }

    final taskIndex = mission.tasks.indexWhere((task) => task.id == taskId);

    if (taskIndex < 0) {
      throw StateError('Task "$taskId" was not found.');
    }

    final task = mission.tasks[taskIndex];

    if (!canTransitionTaskStatus(task.status, status)) {
      throw StateError(
        'Task status cannot change from ${task.status.name} to ${status.name}.',
      );
    }

    final now = DateTime.now();
    final updatedTasks = mission.tasks.toList(growable: false);

    updatedTasks[taskIndex] = task.copyWith(
      status: status,
      completedAt: status == TaskStatus.completed ? now : null,
      clearCompletedAt: status != TaskStatus.completed,
    );

    final updatedMission = mission.copyWith(
      tasks: List<MissionTask>.unmodifiable(updatedTasks),
      updatedAt: now,
    );

    await _repository.saveMission(updatedMission);

    return updatedMission;
  }

  Future<void> deleteMission(String id) {
    return _repository.deleteMission(id);
  }
}
