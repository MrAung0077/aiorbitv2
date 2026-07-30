import 'execution_status.dart';

class MissionExecution {
  const MissionExecution({
    required this.id,
    required this.missionId,
    required this.status,
    required this.progress,
    this.startedAt,
    this.finishedAt,
    this.currentTaskId,
  });

  static const Object _notProvided = Object();

  final String id;
  final String missionId;
  final ExecutionStatus status;

  /// Execution progress from 0.0 to 1.0.
  final double progress;

  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? currentTaskId;

  MissionExecution copyWith({
    String? id,
    String? missionId,
    ExecutionStatus? status,
    double? progress,
    Object? startedAt = _notProvided,
    Object? finishedAt = _notProvided,
    Object? currentTaskId = _notProvided,
  }) {
    return MissionExecution(
      id: id ?? this.id,
      missionId: missionId ?? this.missionId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      startedAt: identical(startedAt, _notProvided)
          ? this.startedAt
          : startedAt as DateTime?,
      finishedAt: identical(finishedAt, _notProvided)
          ? this.finishedAt
          : finishedAt as DateTime?,
      currentTaskId: identical(currentTaskId, _notProvided)
          ? this.currentTaskId
          : currentTaskId as String?,
    );
  }
}
