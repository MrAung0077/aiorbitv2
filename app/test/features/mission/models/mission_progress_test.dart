import 'package:aiorbit/features/mission/models/mission.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:aiorbit/features/mission/models/mission_status.dart';
import 'package:aiorbit/features/mission/models/mission_task.dart';
import 'package:aiorbit/features/mission/models/task_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mission with no tasks has zero progress', () {
    final progress = _mission(const <MissionTask>[]).taskProgress;

    expect(progress.completedTasks, 0);
    expect(progress.totalTasks, 0);
    expect(progress.percent, 0);
    expect(progress.percentage, 0);
    expect(progress.isComplete, isFalse);
  });

  test('mission progress counts only completed tasks', () {
    final progress = _mission(<MissionTask>[
      _task('completed', TaskStatus.completed),
      _task('pending', TaskStatus.pending),
      _task('skipped', TaskStatus.skipped),
      _task('failed', TaskStatus.failed),
    ]).taskProgress;

    expect(progress.completedTasks, 1);
    expect(progress.totalTasks, 4);
    expect(progress.percent, 0.25);
    expect(progress.percentage, 25);
    expect(progress.isComplete, isFalse);
  });

  test('mission with all tasks completed has full progress', () {
    final progress = _mission(<MissionTask>[
      _task('first', TaskStatus.completed),
      _task('second', TaskStatus.completed),
    ]).taskProgress;

    expect(progress.completedTasks, 2);
    expect(progress.totalTasks, 2);
    expect(progress.percent, 1);
    expect(progress.percentage, 100);
    expect(progress.isComplete, isTrue);
  });
}

Mission _mission(List<MissionTask> tasks) {
  final createdAt = DateTime(2026);

  return Mission(
    id: 'mission',
    title: 'Mission',
    goal: 'Complete the mission',
    category: MissionCategory.productivity,
    status: MissionStatus.active,
    createdAt: createdAt,
    updatedAt: createdAt,
    currentTaskIndex: 0,
    progressPercent: 99,
    tasks: tasks,
  );
}

MissionTask _task(String id, TaskStatus status) {
  return MissionTask(
    id: id,
    missionId: 'mission',
    title: id,
    description: id,
    order: 0,
    status: status,
    taskType: 'test',
    createdAt: DateTime(2026),
  );
}
