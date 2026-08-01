import 'package:isar_community/isar.dart';

import '../../models/mission.dart';
import '../../models/mission_category.dart';
import '../../models/mission_progress.dart';
import '../../models/mission_status.dart';
import '../../models/mission_task.dart';
import '../../models/task_status.dart';
import '../models/mission_record.dart';
import '../models/mission_task_record.dart';

class MissionRecordMapper {
  const MissionRecordMapper();

  MissionRecord toRecord(Mission mission, {Id? databaseId}) {
    final missionId = _requireMissionId(mission.id);
    final tasks = _tasksToRecords(mission.tasks, parentMissionId: missionId);
    final createdAt = mission.createdAt;
    final updatedAt = _normalizeUpdatedAt(createdAt, mission.updatedAt);

    return MissionRecord()
      ..id = databaseId ?? Isar.autoIncrement
      ..missionId = missionId
      ..conversationId = _normalizeOptionalId(mission.conversationId)
      ..title = mission.title
      ..goal = mission.goal
      ..category = mission.category.name
      ..status = mission.status.name
      ..createdAt = createdAt
      ..updatedAt = updatedAt
      ..currentTaskIndex = _normalizeCurrentTaskIndex(
        mission.currentTaskIndex,
        tasks.length,
      )
      ..tasks = tasks
      ..userContext = mission.userContext;
  }

  Mission toDomain(MissionRecord record) {
    final missionId = _requireStoredMissionId(record.missionId);
    final tasks = _tasksToDomain(record.tasks, parentMissionId: missionId);
    final taskProgress = MissionProgress.fromTasks(tasks);
    final createdAt = record.createdAt;
    final updatedAt = _normalizeUpdatedAt(createdAt, record.updatedAt);

    return Mission(
      id: missionId,
      title: record.title,
      goal: record.goal,
      category: _parseEnum(
        MissionCategory.values,
        record.category,
        MissionCategory.custom,
      ),
      status: _parseEnum(
        MissionStatus.values,
        record.status,
        MissionStatus.draft,
      ),
      createdAt: createdAt,
      updatedAt: updatedAt,
      currentTaskIndex: _normalizeCurrentTaskIndex(
        record.currentTaskIndex,
        tasks.length,
      ),
      progressPercent: taskProgress.percentage.toDouble(),
      tasks: List<MissionTask>.unmodifiable(tasks),
      conversationId: _normalizeOptionalId(record.conversationId),
      userContext: record.userContext,
    );
  }

  List<MissionTaskRecord> _tasksToRecords(
    List<MissionTask> tasks, {
    required String parentMissionId,
  }) {
    final candidates = <_DomainTaskCandidate>[];
    final taskIds = <String>{};

    for (final entry in tasks.indexed) {
      final taskId = entry.$2.id.trim();

      if (taskId.isEmpty) {
        throw ArgumentError.value(
          entry.$2.id,
          'mission.tasks[${entry.$1}].id',
          'Task ID must not be empty.',
        );
      }

      if (!taskIds.add(taskId)) {
        throw ArgumentError.value(
          taskId,
          'mission.tasks[${entry.$1}].id',
          'Task IDs must be unique within a mission.',
        );
      }

      candidates.add(
        _DomainTaskCandidate(
          sourceIndex: entry.$1,
          taskId: taskId,
          task: entry.$2,
        ),
      );
    }

    candidates.sort((left, right) {
      final orderComparison = left.task.order.compareTo(right.task.order);

      return orderComparison != 0
          ? orderComparison
          : left.sourceIndex.compareTo(right.sourceIndex);
    });

    return candidates.indexed
        .map(
          (entry) => _taskToRecord(
            entry.$2.task,
            taskId: entry.$2.taskId,
            parentMissionId: parentMissionId,
            normalizedOrder: entry.$1,
          ),
        )
        .toList(growable: false);
  }

  List<MissionTask> _tasksToDomain(
    List<MissionTaskRecord> records, {
    required String parentMissionId,
  }) {
    final candidates = <_RecordTaskCandidate>[];
    final taskIds = <String>{};

    for (final entry in records.indexed) {
      final taskId = entry.$2.taskId.trim();

      if (taskId.isEmpty || !taskIds.add(taskId)) {
        continue;
      }

      candidates.add(
        _RecordTaskCandidate(
          sourceIndex: entry.$1,
          taskId: taskId,
          record: entry.$2,
        ),
      );
    }

    candidates.sort((left, right) {
      final orderComparison = left.record.order.compareTo(right.record.order);

      return orderComparison != 0
          ? orderComparison
          : left.sourceIndex.compareTo(right.sourceIndex);
    });

    return candidates.indexed
        .map(
          (entry) => _taskToDomain(
            entry.$2.record,
            taskId: entry.$2.taskId,
            parentMissionId: parentMissionId,
            normalizedOrder: entry.$1,
          ),
        )
        .toList(growable: false);
  }

  MissionTaskRecord _taskToRecord(
    MissionTask task, {
    required String taskId,
    required String parentMissionId,
    required int normalizedOrder,
  }) {
    return MissionTaskRecord()
      ..taskId = taskId
      ..missionId = parentMissionId
      ..title = task.title
      ..description = task.description
      ..order = normalizedOrder
      ..status = task.status.name
      ..taskType = task.taskType
      ..recommendedProvider = task.recommendedProvider
      ..inputContext = task.inputContext
      ..createdAt = task.createdAt
      ..completedAt = task.status == TaskStatus.completed
          ? task.completedAt
          : null;
  }

  MissionTask _taskToDomain(
    MissionTaskRecord record, {
    required String taskId,
    required String parentMissionId,
    required int normalizedOrder,
  }) {
    final status = _parseEnum(
      TaskStatus.values,
      record.status,
      TaskStatus.pending,
    );

    return MissionTask(
      id: taskId,
      missionId: parentMissionId,
      title: record.title,
      description: record.description,
      order: normalizedOrder,
      status: status,
      taskType: record.taskType,
      recommendedProvider: record.recommendedProvider,
      inputContext: record.inputContext,
      createdAt: record.createdAt,
      completedAt: status == TaskStatus.completed ? record.completedAt : null,
    );
  }

  String _requireMissionId(String id) {
    final normalizedId = id.trim();

    if (normalizedId.isEmpty) {
      throw ArgumentError.value(id, 'mission.id', 'Mission ID is required.');
    }

    return normalizedId;
  }

  String _requireStoredMissionId(String id) {
    final normalizedId = id.trim();

    if (normalizedId.isEmpty) {
      throw const FormatException('Persisted mission ID is missing.');
    }

    return normalizedId;
  }

  String? _normalizeOptionalId(String? id) {
    final normalizedId = id?.trim();

    return normalizedId == null || normalizedId.isEmpty ? null : normalizedId;
  }

  DateTime _normalizeUpdatedAt(DateTime createdAt, DateTime updatedAt) {
    return updatedAt.isBefore(createdAt) ? createdAt : updatedAt;
  }

  int _normalizeCurrentTaskIndex(int currentTaskIndex, int taskCount) {
    if (taskCount == 0) {
      return 0;
    }

    return currentTaskIndex.clamp(0, taskCount - 1);
  }

  T _parseEnum<T extends Enum>(List<T> values, String stored, T fallback) {
    final normalizedStored = stored.trim();

    for (final value in values) {
      if (value.name == normalizedStored) {
        return value;
      }
    }

    return fallback;
  }
}

class _DomainTaskCandidate {
  const _DomainTaskCandidate({
    required this.sourceIndex,
    required this.taskId,
    required this.task,
  });

  final int sourceIndex;
  final String taskId;
  final MissionTask task;
}

class _RecordTaskCandidate {
  const _RecordTaskCandidate({
    required this.sourceIndex,
    required this.taskId,
    required this.record,
  });

  final int sourceIndex;
  final String taskId;
  final MissionTaskRecord record;
}
