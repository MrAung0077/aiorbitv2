import 'package:aiorbit/features/mission/models/execution_status.dart';
import 'package:aiorbit/features/mission/models/mission.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:aiorbit/features/mission/models/mission_execution.dart';
import 'package:aiorbit/features/mission/models/mission_status.dart';
import 'package:aiorbit/features/mission/models/mission_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'timeline reuses timestamps from the mission and matching execution',
    () {
      final mission = _mission();
      final startedAt = DateTime(2026, 1, 3, 10);
      final completedAt = DateTime(2026, 1, 3, 11);
      final timeline = MissionTimeline(
        mission: mission,
        execution: MissionExecution(
          id: 'execution',
          missionId: mission.id,
          status: ExecutionStatus.completed,
          progress: 1,
          startedAt: startedAt,
          finishedAt: completedAt,
        ),
      );

      expect(timeline.createdAt, mission.createdAt);
      expect(timeline.updatedAt, mission.updatedAt);
      expect(timeline.startedAt, startedAt);
      expect(timeline.completedAt, completedAt);
    },
  );

  test('finished execution time is not completion unless status completed', () {
    final mission = _mission();
    final timeline = MissionTimeline(
      mission: mission,
      execution: MissionExecution(
        id: 'execution',
        missionId: mission.id,
        status: ExecutionStatus.failed,
        progress: 0.5,
        finishedAt: DateTime(2026, 1, 3, 11),
      ),
    );

    expect(timeline.completedAt, isNull);
  });

  test('timeline date formatter formats values and preserves placeholders', () {
    expect(
      formatMissionTimelineDate(DateTime(2026, 2, 3, 14, 5), placeholder: '—'),
      'Feb 3, 2026, 2:05 PM',
    );
    expect(
      formatMissionTimelineDate(null, placeholder: 'Not started'),
      'Not started',
    );
  });
}

Mission _mission() {
  return Mission(
    id: 'mission',
    title: 'Mission',
    goal: 'Complete the mission',
    category: MissionCategory.productivity,
    status: MissionStatus.active,
    createdAt: DateTime(2026, 1, 2, 9, 30),
    updatedAt: DateTime(2026, 1, 3, 16, 45),
    currentTaskIndex: 0,
    progressPercent: 0,
    tasks: const [],
  );
}
