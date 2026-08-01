import 'execution_status.dart';
import 'mission_execution.dart';

/// Immutable task-scoped outcome that reuses [MissionExecution] for execution
/// identity, status, progress, and timestamps.
class MissionTaskExecution {
  MissionTaskExecution({
    required this.execution,
    this.outputText,
    this.structuredResultReference,
    this.failureMessage,
  }) {
    if (execution.currentTaskId == null) {
      throw ArgumentError.notNull('execution.currentTaskId');
    }

    if (execution.status == ExecutionStatus.failed && failureMessage == null) {
      throw ArgumentError(
        'A failed task execution requires failure information.',
      );
    }
  }

  final MissionExecution execution;
  final String? outputText;
  final String? structuredResultReference;
  final String? failureMessage;

  String get missionId => execution.missionId;

  String get taskId => execution.currentTaskId!;

  ExecutionStatus get status => execution.status;

  DateTime? get startedAt => execution.startedAt;

  DateTime? get finishedAt => execution.finishedAt;
}
