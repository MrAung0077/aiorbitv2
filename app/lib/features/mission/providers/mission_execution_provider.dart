import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/mission_execution_controller.dart';
import '../models/mission_execution.dart';
import '../models/mission_task_execution.dart';
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
}
