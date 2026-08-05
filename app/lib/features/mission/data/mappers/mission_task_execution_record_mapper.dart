import 'package:isar_community/isar.dart';

import '../../models/execution_status.dart';
import '../../models/mission_execution.dart';
import '../../models/mission_task_execution.dart';
import '../models/mission_task_execution_record.dart';

class MissionTaskExecutionRecordMapper {
  const MissionTaskExecutionRecordMapper();

  MissionTaskExecutionRecord toRecord(
    MissionTaskExecution execution, {
    Id? databaseId,
  }) {
    final executionId = _requireId(execution.execution.id, 'execution.id');
    final missionId = _requireId(execution.missionId, 'execution.missionId');
    final taskId = _requireId(execution.taskId, 'execution.taskId');
    final progress = execution.execution.progress.clamp(0.0, 1.0).toDouble();
    final now = DateTime.now().toUtc();

    return MissionTaskExecutionRecord()
      ..id = databaseId ?? Isar.autoIncrement
      ..executionId = executionId
      ..missionId = missionId
      ..taskId = taskId
      ..status = execution.status.name
      ..progress = progress
      ..outputText = _normalizeOptionalText(execution.outputText)
      ..structuredResultReference = _normalizeOptionalText(
        execution.structuredResultReference,
      )
      ..failureMessage = _normalizeOptionalText(execution.failureMessage)
      ..startedAt = execution.startedAt
      ..finishedAt = execution.finishedAt
      ..updatedAt = now;
  }

  MissionTaskExecution toDomain(MissionTaskExecutionRecord record) {
    final executionId = _requireStoredId(record.executionId, 'executionId');
    final missionId = _requireStoredId(record.missionId, 'missionId');
    final taskId = _requireStoredId(record.taskId, 'taskId');
    final status = _parseStatus(record.status);
    final progress = record.progress.clamp(0.0, 1.0).toDouble();

    return MissionTaskExecution(
      execution: MissionExecution(
        id: executionId,
        missionId: missionId,
        status: status,
        progress: progress,
        startedAt: record.startedAt,
        finishedAt: record.finishedAt,
        currentTaskId: taskId,
      ),
      outputText: _normalizeOptionalText(record.outputText),
      structuredResultReference: _normalizeOptionalText(
        record.structuredResultReference,
      ),
      failureMessage: _normalizeOptionalText(record.failureMessage),
    );
  }

  String _requireId(String value, String name) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(value, name, '$name is required.');
    }

    return normalized;
  }

  String _requireStoredId(String value, String fieldName) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw FormatException('Persisted task execution $fieldName is missing.');
    }

    return normalized;
  }

  String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();

    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  ExecutionStatus _parseStatus(String stored) {
    final normalized = stored.trim();

    for (final status in ExecutionStatus.values) {
      if (status.name == normalized) {
        return status;
      }
    }

    throw FormatException('Unknown persisted execution status: $stored');
  }
}
