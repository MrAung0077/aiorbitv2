import '../models/execution_status.dart';
import '../models/mission_execution.dart';

class MissionExecutionController {
  MissionExecutionController();

  MissionExecution createExecution({
    required String executionId,
    required String missionId,
  }) {
    return MissionExecution(
      id: executionId,
      missionId: missionId,
      status: ExecutionStatus.queued,
      progress: 0,
    );
  }

  MissionExecution prepare(MissionExecution execution) {
    return execution.copyWith(status: ExecutionStatus.preparing);
  }

  MissionExecution start(MissionExecution execution) {
    return execution.copyWith(
      status: ExecutionStatus.running,
      startedAt: execution.startedAt ?? DateTime.now(),
    );
  }

  MissionExecution updateProgress(
    MissionExecution execution, {
    required double progress,
    String? currentTaskId,
  }) {
    final normalizedProgress = progress.clamp(0.0, 1.0).toDouble();

    return execution.copyWith(
      progress: normalizedProgress,
      currentTaskId: currentTaskId,
    );
  }

  MissionExecution pause(MissionExecution execution) {
    return execution.copyWith(status: ExecutionStatus.paused);
  }

  MissionExecution complete(MissionExecution execution) {
    return execution.copyWith(
      status: ExecutionStatus.completed,
      progress: 1,
      finishedAt: DateTime.now(),
      currentTaskId: null,
    );
  }

  MissionExecution fail(MissionExecution execution) {
    return execution.copyWith(
      status: ExecutionStatus.failed,
      finishedAt: DateTime.now(),
    );
  }

  MissionExecution cancel(MissionExecution execution) {
    return execution.copyWith(
      status: ExecutionStatus.cancelled,
      finishedAt: DateTime.now(),
      currentTaskId: null,
    );
  }
}
