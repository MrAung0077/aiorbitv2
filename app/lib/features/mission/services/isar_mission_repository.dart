import 'package:isar_community/isar.dart';

import '../data/mappers/mission_record_mapper.dart';
import '../data/models/mission_record.dart';
import '../models/mission.dart';
import 'mission_repository.dart';

class IsarMissionRepository implements MissionRepository {
  IsarMissionRepository({
    required Isar isar,
    MissionRecordMapper mapper = const MissionRecordMapper(),
  }) : this._(isar, mapper);

  IsarMissionRepository._(this._isar, this._mapper);

  final Isar _isar;
  final MissionRecordMapper _mapper;

  @override
  Future<void> saveMission(Mission mission) async {
    final record = _mapper.toRecord(mission);

    await _isar.writeTxn(() async {
      final allRecords = await _isar.missionRecords.where().findAll();
      final existingRecords =
          allRecords
              .where(
                (existing) => existing.missionId.trim() == record.missionId,
              )
              .toList(growable: false)
            ..sort((left, right) => left.id.compareTo(right.id));

      if (existingRecords.isNotEmpty) {
        record.id = existingRecords.first.id;
      }

      await _isar.missionRecords.put(record);

      if (existingRecords.length > 1) {
        await _isar.missionRecords.deleteAll(
          existingRecords.skip(1).map((duplicate) => duplicate.id).toList(),
        );
      }
    });
  }

  @override
  Future<Mission?> getMission(String id) async {
    final normalizedId = id.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    final records = await _isar.missionRecords.where().findAll();
    _MissionRecordCandidate? latest;

    for (final candidate in _validCandidates(records)) {
      if (candidate.mission.id != normalizedId) {
        continue;
      }

      if (latest == null || _isNewer(candidate, latest)) {
        latest = candidate;
      }
    }

    return latest?.mission;
  }

  @override
  Future<List<Mission>> getAllMissions() async {
    final records = await _isar.missionRecords.where().findAll();
    records.sort((left, right) => left.id.compareTo(right.id));
    final latestByMissionId = <String, _MissionRecordCandidate>{};

    for (final candidate in _validCandidates(records)) {
      final current = latestByMissionId[candidate.mission.id];

      if (current == null || _isNewer(candidate, current)) {
        latestByMissionId[candidate.mission.id] = candidate;
      }
    }

    return List<Mission>.unmodifiable(
      latestByMissionId.values.map((candidate) => candidate.mission),
    );
  }

  @override
  Future<void> deleteMission(String id) async {
    final normalizedId = id.trim();

    if (normalizedId.isEmpty) {
      return;
    }

    await _isar.writeTxn(() async {
      final records = await _isar.missionRecords.where().findAll();
      final matchingIds = records
          .where((record) => record.missionId.trim() == normalizedId)
          .map((record) => record.id)
          .toList(growable: false);

      if (matchingIds.isNotEmpty) {
        await _isar.missionRecords.deleteAll(matchingIds);
      }
    });
  }

  Iterable<_MissionRecordCandidate> _validCandidates(
    Iterable<MissionRecord> records,
  ) sync* {
    for (final record in records) {
      try {
        yield _MissionRecordCandidate(
          databaseId: record.id,
          mission: _mapper.toDomain(record),
        );
      } on FormatException {
        continue;
      }
    }
  }

  bool _isNewer(
    _MissionRecordCandidate candidate,
    _MissionRecordCandidate current,
  ) {
    final timestampComparison = candidate.mission.updatedAt.compareTo(
      current.mission.updatedAt,
    );

    return timestampComparison > 0 ||
        (timestampComparison == 0 && candidate.databaseId > current.databaseId);
  }
}

class _MissionRecordCandidate {
  const _MissionRecordCandidate({
    required this.databaseId,
    required this.mission,
  });

  final Id databaseId;
  final Mission mission;
}
