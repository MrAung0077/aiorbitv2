import 'package:aiorbit/features/mission/models/mission.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:aiorbit/features/mission/models/mission_status.dart';
import 'package:aiorbit/features/mission/models/mission_task.dart';
import 'package:aiorbit/features/mission/models/task_status.dart';
import 'package:aiorbit/features/mission/services/chat_mission_result_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const adapter = ChatMissionResultAdapter();

  test('uses accepted persisted output and excludes non-deliverables', () {
    final result = adapter.fromMission(
      _mission(<MissionTask>[
        _task(id: 'completed', title: 'Final brief', output: 'Saved brief'),
        _task(
          id: 'pending',
          title: 'Draft',
          status: TaskStatus.pending,
          output: 'Temporary draft',
        ),
        _task(id: 'blank', title: 'Empty', output: '   '),
      ]),
    );

    expect(result?.deliverables, hasLength(1));
    expect(result?.deliverables.single.title, 'Final brief');
    expect(result?.deliverables.single.content, 'Saved brief');
  });

  test('packages multiple completed deliverables in order', () {
    final result = adapter.fromMission(
      _mission(<MissionTask>[
        _task(id: 'brief', title: 'Brief', output: 'Final brief'),
        _task(id: 'plan', title: 'Plan', output: 'Final plan'),
      ]),
    );

    expect(
      result?.deliverables.map((deliverable) => deliverable.title),
      <String>['Brief', 'Plan'],
    );
    expect(
      result?.deliverables.map((deliverable) => deliverable.content),
      <String>['Final brief', 'Final plan'],
    );
  });

  test('returns no result without an accepted persisted output', () {
    expect(
      adapter.fromMission(
        _mission(<MissionTask>[
          _task(id: 'pending', title: 'Draft', status: TaskStatus.pending),
        ]),
      ),
      isNull,
    );
  });
}

Mission _mission(List<MissionTask> tasks) {
  final createdAt = DateTime(2026, 1, 1);

  return Mission(
    id: 'mission',
    title: 'Internal title',
    goal: 'Internal goal',
    category: MissionCategory.business,
    status: MissionStatus.completed,
    createdAt: createdAt,
    updatedAt: createdAt,
    currentTaskIndex: 0,
    progressPercent: 1,
    tasks: tasks,
  );
}

MissionTask _task({
  required String id,
  required String title,
  String? output,
  TaskStatus status = TaskStatus.completed,
}) {
  return MissionTask(
    id: id,
    missionId: 'mission',
    title: title,
    description: 'Internal description',
    taskType: 'research',
    order: id == 'plan' ? 1 : 0,
    status: status,
    output: output,
    createdAt: DateTime(2026, 1, 1),
  );
}
