import 'package:aiorbit/features/mission/models/mission.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:aiorbit/features/mission/models/mission_status.dart';
import 'package:aiorbit/features/mission/services/memory_mission_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('memory mission repository behavior remains unchanged', () async {
    final repository = MemoryMissionRepository();
    final first = _mission('first');
    final second = _mission('second');

    await repository.saveMission(first);
    await repository.saveMission(second);

    expect(await repository.getMission(first.id), same(first));
    expect(
      await repository.getAllMissions(),
      containsAll(<Mission>[first, second]),
    );

    await repository.deleteMission(first.id);

    expect(await repository.getMission(first.id), isNull);
    expect(await repository.getMission(second.id), same(second));
  });
}

Mission _mission(String id) {
  final createdAt = DateTime.utc(2026, 3, 6);

  return Mission(
    id: id,
    title: 'Mission $id',
    goal: 'Preserve existing repository behavior',
    category: MissionCategory.productivity,
    status: MissionStatus.active,
    createdAt: createdAt,
    updatedAt: createdAt,
    currentTaskIndex: 0,
    progressPercent: 0,
    tasks: const [],
  );
}
