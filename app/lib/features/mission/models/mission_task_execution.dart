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
    if (execution.currentTaskId == null ||
        execution.currentTaskId!.trim().isEmpty) {
      throw ArgumentError('A task execution requires a valid currentTaskId.');
    }

    if (execution.status == ExecutionStatus.failed &&
        (failureMessage == null || failureMessage!.trim().isEmpty)) {
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

  bool get hasOutput => outputText?.trim().isNotEmpty ?? false;

  bool get hasStructuredResult =>
      structuredResultReference?.trim().isNotEmpty ?? false;

  bool get hasFailure =>
      status == ExecutionStatus.failed &&
      (failureMessage?.trim().isNotEmpty ?? false);
}
