import '../models/mission.dart';
import '../models/execution_status.dart';
import '../models/mission_suggestion.dart';
import '../models/mission_task.dart';
import '../models/mission_task_execution.dart';
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
  }) {
    return _updateTaskStatus(
      missionId: missionId,
      taskId: taskId,
      status: status,
    );
  }

  Future<Mission> _updateTaskStatus({
    required String missionId,
    required String taskId,
    required TaskStatus status,
    String? acceptedOutput,
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

    final updatedTask = task.copyWith(
      status: status,
      completedAt: status == TaskStatus.completed ? now : null,
      clearCompletedAt: status != TaskStatus.completed,
    );

    updatedTasks[taskIndex] = acceptedOutput == null
        ? updatedTask
        : updatedTask.copyWith(output: acceptedOutput);

    final updatedMission = mission.copyWith(
      tasks: List<MissionTask>.unmodifiable(updatedTasks),
      updatedAt: now,
    );

    await _repository.saveMission(updatedMission);

    return updatedMission;
  }

  Future<Mission> acceptTaskResult({
    required String missionId,
    required String taskId,
    required MissionTaskExecution execution,
  }) async {
    final outputText = execution.outputText?.trim();
    final structuredResultReference = execution.structuredResultReference
        ?.trim();
    final acceptedOutput = outputText?.isNotEmpty == true
        ? outputText!
        : structuredResultReference?.isNotEmpty == true
        ? structuredResultReference!
        : null;

    if (execution.status != ExecutionStatus.completed ||
        execution.missionId != missionId ||
        execution.taskId != taskId ||
        acceptedOutput == null) {
      throw StateError('A matching completed task execution is required.');
    }

    final mission = await _repository.getMission(missionId);

    if (mission == null) {
      throw StateError('Mission "$missionId" was not found.');
    }

    final taskIndex = mission.tasks.indexWhere((task) => task.id == taskId);

    if (taskIndex < 0) {
      throw StateError('Task "$taskId" was not found.');
    }

    final task = mission.tasks[taskIndex];

    if (task.status == TaskStatus.pending) {
      await updateTaskStatus(
        missionId: missionId,
        taskId: taskId,
        status: TaskStatus.inProgress,
      );
    } else if (task.status != TaskStatus.inProgress) {
      throw StateError('This task cannot accept an execution result.');
    }

    return _updateTaskStatus(
      missionId: missionId,
      taskId: taskId,
      status: TaskStatus.completed,
      acceptedOutput: acceptedOutput,
    );
  }

  Future<void> deleteMission(String id) {
    return _repository.deleteMission(id);
  }
}
