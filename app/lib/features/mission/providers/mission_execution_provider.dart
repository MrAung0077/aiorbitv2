import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/mission_execution_controller.dart';
import '../models/execution_status.dart';
import '../models/mission.dart';
import '../models/mission_execution.dart';
import '../models/mission_task.dart';
import '../models/mission_task_execution.dart';
import '../models/task_status.dart';
import 'mission_provider.dart';
import 'mission_task_execution_provider.dart';

final missionExecutionControllerProvider = Provider<MissionExecutionController>(
  (ref) {
    return MissionExecutionController();
  },
);

final missionExecutionProvider =
    NotifierProvider<MissionExecutionNotifier, MissionExecution?>(
      MissionExecutionNotifier.new,
    );

class MissionExecutionNotifier extends Notifier<MissionExecution?> {
  String? _activeMissionId;

  MissionExecutionController get _controller {
    return ref.read(missionExecutionControllerProvider);
  }

  @override
  MissionExecution? build() {
    return null;
  }

  void createExecution({
    required String executionId,
    required String missionId,
  }) {
    state = _controller.createExecution(
      executionId: executionId,
      missionId: missionId,
    );
  }

  void prepare() {
    final execution = state;

    if (execution == null) {
      return;
    }

    state = _controller.prepare(execution);
  }

  void start() {
    final execution = state;

    if (execution == null) {
      return;
    }

    state = _controller.start(execution);
  }

  void updateProgress({required double progress, String? currentTaskId}) {
    final execution = state;

    if (execution == null) {
      return;
    }

    state = _controller.updateProgress(
      execution,
      progress: progress,
      currentTaskId: currentTaskId,
    );
  }

  void pause() {
    final execution = state;

    if (execution == null) {
      return;
    }

    state = _controller.pause(execution);
  }

  void complete() {
    final execution = state;

    if (execution == null) {
      return;
    }

    state = _controller.complete(execution);
  }

  void fail() {
    final execution = state;

    if (execution == null) {
      return;
    }

    state = _controller.fail(execution);
  }

  void cancel() {
    final execution = state;

    if (execution == null) {
      return;
    }

    state = _controller.cancel(execution);
  }

  /// Stops the currently controlled Mission. Completed task outputs stay on
  /// the Mission; the active task's late transport result cannot be accepted.
  Future<Mission?> cancelActiveMission() async {
    final execution = state;
    final missionId = _activeMissionId;
    if (execution == null || missionId == null) {
      return null;
    }

    cancel();
    final taskId = execution.currentTaskId;
    if (taskId != null) {
      await ref
          .read(missionTaskExecutionProvider.notifier)
          .cancelTask(missionId: missionId, taskId: taskId);
    }
    return ref.read(missionControllerProvider).cancelMission(missionId: missionId);
  }

  void clear() {
    state = null;
  }

  Future<MissionTaskExecution> executeTask({
    required String missionId,
    required String taskId,
  }) {
    return ref
        .read(missionTaskExecutionProvider.notifier)
        .executeTask(missionId: missionId, taskId: taskId);
  }

  Future<Mission> runMission({required String missionId}) async {
    final normalizedMissionId = missionId.trim();
    final currentExecution = state;

    if (normalizedMissionId.isEmpty) {
      throw StateError('Mission ID is required.');
    }

    if (_activeMissionId != null ||
        currentExecution?.status == ExecutionStatus.preparing ||
        currentExecution?.status == ExecutionStatus.running) {
      throw StateError('A mission is already running.');
    }

    if (ref
        .read(missionTaskExecutionProvider)
        .any((execution) => execution.status == ExecutionStatus.running)) {
      throw StateError('A task is already running.');
    }

    _activeMissionId = normalizedMissionId;

    try {
      final missionController = ref.read(missionControllerProvider);
      final initialMission = await missionController.getMission(
        normalizedMissionId,
      );

      if (initialMission == null) {
        throw StateError('Mission "$normalizedMissionId" was not found.');
      }

      var mission = initialMission;

      createExecution(
        executionId:
            'execution-$normalizedMissionId-'
            '${DateTime.now().microsecondsSinceEpoch}',
        missionId: normalizedMissionId,
      );
      prepare();
      start();

      final orderedTasks = _orderedTasks(mission.tasks);
      final totalTasks = orderedTasks.length;

      if (totalTasks == 0) {
        complete();
        return mission;
      }

      _updateMissionProgress(mission, totalTasks: totalTasks);
      final taskExecutionNotifier = ref.read(
        missionTaskExecutionProvider.notifier,
      );

      for (final orderedTask in orderedTasks) {
        if (_wasCancelled(normalizedMissionId)) {
          return await missionController.getMission(normalizedMissionId) ??
              mission;
        }
        final latestMission = await missionController.getMission(
          normalizedMissionId,
        );

        if (latestMission == null) {
          throw StateError('Mission "$normalizedMissionId" was not found.');
        }

        mission = latestMission;

        final taskIndex = mission.tasks.indexWhere(
          (task) => task.id == orderedTask.id,
        );

        if (taskIndex < 0) {
          throw StateError('Task "${orderedTask.id}" was not found.');
        }

        final task = mission.tasks[taskIndex];

        if (task.status == TaskStatus.completed) {
          _updateMissionProgress(mission, totalTasks: totalTasks);
          continue;
        }

        if (!_isTaskEligible(task)) {
          continue;
        }

        updateProgress(
          progress: mission.taskProgress.completedTasks / totalTasks,
          currentTaskId: task.id,
        );

        final result = await taskExecutionNotifier.executeTask(
          missionId: normalizedMissionId,
          taskId: task.id,
        );

        if (_wasCancelled(normalizedMissionId)) {
          return await missionController.getMission(normalizedMissionId) ??
              mission;
        }

        if (result.status != ExecutionStatus.completed ||
            !_hasUsableResult(result)) {
          fail();
          return await missionController.getMission(normalizedMissionId) ??
              mission;
        }

        mission = await taskExecutionNotifier.acceptResult(
          missionId: normalizedMissionId,
          taskId: task.id,
        );
        _updateMissionProgress(mission, totalTasks: totalTasks);
      }

      complete();

      return await missionController.getMission(normalizedMissionId) ?? mission;
    } catch (_) {
      final execution = state;

      if (execution?.status == ExecutionStatus.preparing ||
          execution?.status == ExecutionStatus.running) {
        fail();
      }

      rethrow;
    } finally {
      _activeMissionId = null;
    }
  }

  List<MissionTask> _orderedTasks(List<MissionTask> tasks) {
    final indexedTasks = tasks.indexed.toList(growable: false)
      ..sort((left, right) {
        final orderComparison = left.$2.order.compareTo(right.$2.order);

        return orderComparison != 0
            ? orderComparison
            : left.$1.compareTo(right.$1);
      });

    return indexedTasks.map((entry) => entry.$2).toList(growable: false);
  }

  bool _wasCancelled(String missionId) {
    return _activeMissionId == missionId &&
        state?.status == ExecutionStatus.cancelled;
  }

  bool _isTaskEligible(MissionTask task) {
    return task.status == TaskStatus.pending ||
        task.status == TaskStatus.inProgress;
  }

  bool _hasUsableResult(MissionTaskExecution execution) {
    return execution.outputText?.trim().isNotEmpty == true ||
        execution.structuredResultReference?.trim().isNotEmpty == true;
  }

  void _updateMissionProgress(Mission mission, {required int totalTasks}) {
    updateProgress(progress: mission.taskProgress.completedTasks / totalTasks);
  }
}
