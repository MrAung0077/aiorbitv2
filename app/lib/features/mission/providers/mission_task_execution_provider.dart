import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_provider_registry.dart';
import '../../../core/ai/ai_router.dart';
import '../../../core/ai/ai_service.dart';
import '../models/execution_status.dart';
import '../models/mission.dart';
import '../models/mission_execution.dart';
import '../models/mission_task.dart';
import '../models/mission_task_execution.dart';
import '../models/task_status.dart';
import '../services/ai_service_mission_task_executor.dart';
import '../services/mission_task_executor.dart';
import 'mission_provider.dart';

final missionAIServiceProvider = Provider<AIService>((ref) {
  return AIService(router: AIRouter(providers: AIProviderRegistry.providers()));
});

final missionTaskExecutorProvider = Provider<MissionTaskExecutor>((ref) {
  return AIServiceMissionTaskExecutor(ref.watch(missionAIServiceProvider));
});

final missionTaskExecutionClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final missionTaskExecutionProvider =
    NotifierProvider<MissionTaskExecutionNotifier, List<MissionTaskExecution>>(
      MissionTaskExecutionNotifier.new,
    );

class MissionTaskExecutionNotifier
    extends Notifier<List<MissionTaskExecution>> {
  static const _safeFailureMessage =
      'Unable to complete this task. Please try again.';

  String? _activeTaskKey;
  final Set<String> _activeAcceptanceKeys = <String>{};
  final Set<String> _restoringMissionIds = <String>{};
  final Set<String> _restoredMissionIds = <String>{};

  @override
  List<MissionTaskExecution> build() {
    return const <MissionTaskExecution>[];
  }

  MissionTaskExecution? executionFor({
    required String missionId,
    required String taskId,
  }) {
    for (final execution in state.reversed) {
      if (execution.missionId == missionId && execution.taskId == taskId) {
        return execution;
      }
    }

    return null;
  }

  bool isIdle({required String missionId, required String taskId}) {
    return executionFor(missionId: missionId, taskId: taskId) == null;
  }

  Future<void> restoreMissionExecutions(String missionId) async {
    final normalizedMissionId = missionId.trim();

    if (normalizedMissionId.isEmpty ||
        _restoredMissionIds.contains(normalizedMissionId) ||
        !_restoringMissionIds.add(normalizedMissionId)) {
      return;
    }

    if (!ref.read(isarInitializedProvider)) {
      _restoringMissionIds.remove(normalizedMissionId);
      return;
    }

    try {
      final storedExecutions = await ref
          .read(missionTaskExecutionRepositoryProvider)
          .getExecutionsForMission(normalizedMissionId);

      final restoredExecutions = <MissionTaskExecution>[];

      for (final stored in storedExecutions) {
        if (stored.status == ExecutionStatus.running ||
            stored.status == ExecutionStatus.preparing) {
          final recovered = MissionTaskExecution(
            execution: stored.execution.copyWith(
              status: ExecutionStatus.failed,
              progress: 0,
              finishedAt:
                  stored.finishedAt ??
                  ref.read(missionTaskExecutionClockProvider)(),
            ),
            failureMessage:
                'This task was interrupted before it finished. Please retry.',
          );

          await ref
              .read(missionTaskExecutionRepositoryProvider)
              .saveExecution(recovered);

          restoredExecutions.add(recovered);
          continue;
        }

        restoredExecutions.add(stored);
      }

      final restoredKeys = restoredExecutions
          .map((execution) => '${execution.missionId}::${execution.taskId}')
          .toSet();

      state = List<MissionTaskExecution>.unmodifiable(<MissionTaskExecution>[
        for (final current in state)
          if (!restoredKeys.contains('${current.missionId}::${current.taskId}'))
            current,
        ...restoredExecutions,
      ]);

      _restoredMissionIds.add(normalizedMissionId);
    } finally {
      _restoringMissionIds.remove(normalizedMissionId);
    }
  }

  Future<Mission> acceptResult({
    required String missionId,
    required String taskId,
  }) async {
    final normalizedMissionId = missionId.trim();
    final normalizedTaskId = taskId.trim();
    final execution = executionFor(
      missionId: normalizedMissionId,
      taskId: normalizedTaskId,
    );

    if (execution?.status != ExecutionStatus.completed ||
        !_hasUsableResult(execution!)) {
      throw StateError('A completed task execution result is required.');
    }

    final taskKey = '$normalizedMissionId::$normalizedTaskId';

    if (!_activeAcceptanceKeys.add(taskKey)) {
      throw StateError('This task result is already being accepted.');
    }

    try {
      return await ref
          .read(missionControllerProvider)
          .acceptTaskResult(
            missionId: normalizedMissionId,
            taskId: normalizedTaskId,
          );
    } finally {
      _activeAcceptanceKeys.remove(taskKey);
    }
  }

  Future<MissionTaskExecution> executeTask({
    required String missionId,
    required String taskId,
  }) async {
    final normalizedMissionId = missionId.trim();
    final normalizedTaskId = taskId.trim();

    if (normalizedMissionId.isEmpty) {
      throw StateError('Mission ID is required.');
    }

    if (normalizedTaskId.isEmpty) {
      throw StateError('Task ID is required.');
    }

    final taskKey = '$normalizedMissionId::$normalizedTaskId';

    if (_activeTaskKey != null) {
      if (_activeTaskKey == taskKey) {
        throw StateError('This task is already running.');
      }

      throw StateError('Another task is already running.');
    }

    _activeTaskKey = taskKey;

    try {
      final mission = await ref
          .read(missionControllerProvider)
          .getMission(normalizedMissionId);

      if (mission == null) {
        throw StateError('Mission "$normalizedMissionId" was not found.');
      }

      final taskIndex = mission.tasks.indexWhere(
        (task) => task.id == normalizedTaskId,
      );

      if (taskIndex < 0) {
        throw StateError('Task "$normalizedTaskId" was not found.');
      }

      final task = mission.tasks[taskIndex];
      _validateTaskEligibility(task);

      final startedAt = ref.read(missionTaskExecutionClockProvider)();
      final running = MissionTaskExecution(
        execution: MissionExecution(
          id: 'task-${mission.id}-${task.id}-${startedAt.microsecondsSinceEpoch}',
          missionId: mission.id,
          status: ExecutionStatus.running,
          progress: 0,
          startedAt: startedAt,
          currentTaskId: task.id,
        ),
      );

      await _publishAndPersist(running);

      try {
        final result = await ref
            .read(missionTaskExecutorProvider)
            .execute(mission: mission, task: task);

        if (result.missionId != mission.id || result.taskId != task.id) {
          throw StateError('Task execution returned mismatched identifiers.');
        }

        if (result.status == ExecutionStatus.completed) {
          if (!_hasUsableResult(result)) {
            throw StateError('Task execution returned no usable result.');
          }

          final latestMission = await ref
              .read(missionControllerProvider)
              .getMission(mission.id);

          if (latestMission == null ||
              !latestMission.tasks.any((current) => current.id == task.id)) {
            throw StateError('Mission task is no longer available.');
          }

          await _publishAndPersist(result);
          return result;
        }

        if (result.status == ExecutionStatus.failed) {
          return _publishSafeFailure(result.execution);
        }

        throw StateError('Task execution did not reach a final state.');
      } catch (_) {
        return _publishSafeFailure(running.execution);
      }
    } finally {
      _activeTaskKey = null;
    }
  }

  void _validateTaskEligibility(MissionTask task) {
    if (task.status != TaskStatus.pending &&
        task.status != TaskStatus.inProgress) {
      throw StateError('This task is not eligible for execution.');
    }

    if (task.title.trim().isEmpty ||
        task.description.trim().isEmpty ||
        task.taskType.trim().isEmpty) {
      throw StateError('Task input is incomplete.');
    }
  }

  bool _hasUsableResult(MissionTaskExecution execution) {
    return execution.outputText?.trim().isNotEmpty == true ||
        execution.structuredResultReference?.trim().isNotEmpty == true;
  }

  Future<MissionTaskExecution> _publishSafeFailure(
    MissionExecution execution,
  ) async {
    final failed = MissionTaskExecution(
      execution: execution.copyWith(
        status: ExecutionStatus.failed,
        progress: 0,
        finishedAt:
            execution.finishedAt ??
            ref.read(missionTaskExecutionClockProvider)(),
      ),
      failureMessage: _safeFailureMessage,
    );

    await _publishAndPersist(failed);
    return failed;
  }

  Future<void> _publishAndPersist(MissionTaskExecution execution) async {
    state = List<MissionTaskExecution>.unmodifiable(<MissionTaskExecution>[
      for (final current in state)
        if (current.missionId != execution.missionId ||
            current.taskId != execution.taskId)
          current,
      execution,
    ]);

    await ref
        .read(missionTaskExecutionRepositoryProvider)
        .saveExecution(execution);
  }
}
