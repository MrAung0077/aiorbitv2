import 'package:isar_community/isar.dart';

import '../data/mappers/mission_task_execution_record_mapper.dart';
import '../data/models/mission_task_execution_record.dart';
import '../models/mission_task_execution.dart';
import 'mission_task_execution_repository.dart';

class IsarMissionTaskExecutionRepository
    implements MissionTaskExecutionRepository {
  IsarMissionTaskExecutionRepository({
    required Isar isar,
    MissionTaskExecutionRecordMapper mapper =
        const MissionTaskExecutionRecordMapper(),
  }) : this._(isar, mapper);

  IsarMissionTaskExecutionRepository._(this._isar, this._mapper);

  final Isar _isar;
  final MissionTaskExecutionRecordMapper _mapper;

  @override
  Future<void> saveExecution(MissionTaskExecution execution) async {
    final record = _mapper.toRecord(execution);

    await _isar.writeTxn(() async {
      final records = await _isar.missionTaskExecutionRecords.where().findAll();

      final matchingRecords =
          records
              .where(
                (existing) =>
                    existing.missionId.trim() == record.missionId &&
                    existing.taskId.trim() == record.taskId,
              )
              .toList(growable: false)
            ..sort((left, right) => left.id.compareTo(right.id));

      if (matchingRecords.isNotEmpty) {
        record.id = matchingRecords.first.id;
      }

      await _isar.missionTaskExecutionRecords.put(record);

      if (matchingRecords.length > 1) {
        await _isar.missionTaskExecutionRecords.deleteAll(
          matchingRecords
              .skip(1)
              .map((duplicate) => duplicate.id)
              .toList(growable: false),
        );
      }
    });
  }

  @override
  Future<MissionTaskExecution?> getExecution({
    required String missionId,
    required String taskId,
  }) async {
    final normalizedMissionId = missionId.trim();
    final normalizedTaskId = taskId.trim();

    if (normalizedMissionId.isEmpty || normalizedTaskId.isEmpty) {
      return null;
    }

    final records = await _isar.missionTaskExecutionRecords.where().findAll();
    _ExecutionRecordCandidate? latest;

    for (final candidate in _validCandidates(records)) {
      if (candidate.execution.missionId != normalizedMissionId ||
          candidate.execution.taskId != normalizedTaskId) {
        continue;
      }

      if (latest == null || _isNewer(candidate, latest)) {
        latest = candidate;
      }
    }

    return latest?.execution;
  }

  @override
  Future<List<MissionTaskExecution>> getExecutionsForMission(
    String missionId,
  ) async {
    final normalizedMissionId = missionId.trim();

    if (normalizedMissionId.isEmpty) {
      return const <MissionTaskExecution>[];
    }

    final records = await _isar.missionTaskExecutionRecords.where().findAll();
    final latestByTaskId = <String, _ExecutionRecordCandidate>{};

    for (final candidate in _validCandidates(records)) {
      if (candidate.execution.missionId != normalizedMissionId) {
        continue;
      }

      final current = latestByTaskId[candidate.execution.taskId];

      if (current == null || _isNewer(candidate, current)) {
        latestByTaskId[candidate.execution.taskId] = candidate;
      }
    }

    final executions = latestByTaskId.values.toList(growable: false)
      ..sort((left, right) {
        final startedComparison = _compareNullableDates(
          left.execution.startedAt,
          right.execution.startedAt,
        );

        if (startedComparison != 0) {
          return startedComparison;
        }

        return left.databaseId.compareTo(right.databaseId);
      });

    return List<MissionTaskExecution>.unmodifiable(
      executions.map((candidate) => candidate.execution),
    );
  }

  @override
  Future<void> deleteExecution({
    required String missionId,
    required String taskId,
  }) async {
    final normalizedMissionId = missionId.trim();
    final normalizedTaskId = taskId.trim();

    if (normalizedMissionId.isEmpty || normalizedTaskId.isEmpty) {
      return;
    }

    await _isar.writeTxn(() async {
      final records = await _isar.missionTaskExecutionRecords.where().findAll();

      final matchingIds = records
          .where(
            (record) =>
                record.missionId.trim() == normalizedMissionId &&
                record.taskId.trim() == normalizedTaskId,
          )
          .map((record) => record.id)
          .toList(growable: false);

      if (matchingIds.isNotEmpty) {
        await _isar.missionTaskExecutionRecords.deleteAll(matchingIds);
      }
    });
  }

  @override
  Future<void> deleteExecutionsForMission(String missionId) async {
    final normalizedMissionId = missionId.trim();

    if (normalizedMissionId.isEmpty) {
      return;
    }

    await _isar.writeTxn(() async {
      final records = await _isar.missionTaskExecutionRecords.where().findAll();

      final matchingIds = records
          .where((record) => record.missionId.trim() == normalizedMissionId)
          .map((record) => record.id)
          .toList(growable: false);

      if (matchingIds.isNotEmpty) {
        await _isar.missionTaskExecutionRecords.deleteAll(matchingIds);
      }
    });
  }

  Iterable<_ExecutionRecordCandidate> _validCandidates(
    Iterable<MissionTaskExecutionRecord> records,
  ) sync* {
    for (final record in records) {
      try {
        yield _ExecutionRecordCandidate(
          databaseId: record.id,
          updatedAt: record.updatedAt,
          execution: _mapper.toDomain(record),
        );
      } on FormatException {
        continue;
      } on ArgumentError {
        continue;
      }
    }
  }

  bool _isNewer(
    _ExecutionRecordCandidate candidate,
    _ExecutionRecordCandidate current,
  ) {
    final updatedComparison = candidate.updatedAt.compareTo(current.updatedAt);

    return updatedComparison > 0 ||
        (updatedComparison == 0 && candidate.databaseId > current.databaseId);
  }

  int _compareNullableDates(DateTime? left, DateTime? right) {
    if (left == null && right == null) {
      return 0;
    }

    if (left == null) {
      return -1;
    }

    if (right == null) {
      return 1;
    }

    return left.compareTo(right);
  }
}

class _ExecutionRecordCandidate {
  const _ExecutionRecordCandidate({
    required this.databaseId,
    required this.updatedAt,
    required this.execution,
  });

  final Id databaseId;
  final DateTime updatedAt;
  final MissionTaskExecution execution;
}
