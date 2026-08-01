import 'package:aiorbit/features/mission/models/mission.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:aiorbit/features/mission/models/mission_status.dart';
import 'package:aiorbit/features/mission/models/mission_task.dart';
import 'package:aiorbit/features/mission/models/task_status.dart';
import 'package:aiorbit/features/mission/services/mission_intelligence_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = MissionIntelligenceService();

  test('empty mission has no recommendation and still requires action', () {
    final mission = _mission(const <MissionTask>[]);

    final result = service.analyze(mission);

    expect(result.hasIncompleteTasks, isFalse);
    expect(result.nextRecommendedTask, isNull);
    expect(result.requiresUserAction, isTrue);
    expect(result.isCompleted, isFalse);
  });

  test('completed mission is detected from task-derived progress', () {
    final mission = _mission(<MissionTask>[
      _task('task-1', order: 0, status: TaskStatus.completed),
      _task('task-2', order: 1, status: TaskStatus.completed),
    ]);

    final result = service.analyze(mission);

    expect(result.hasIncompleteTasks, isFalse);
    expect(result.nextRecommendedTask, isNull);
    expect(result.requiresUserAction, isFalse);
    expect(result.isCompleted, isTrue);
  });

  test('recommends the first pending task by stable task order', () {
    final laterPending = _task(
      'task-later',
      order: 2,
      status: TaskStatus.pending,
    );
    final firstPending = _task(
      'task-first',
      order: 1,
      status: TaskStatus.pending,
    );
    final mission = _mission(<MissionTask>[
      laterPending,
      _task('task-completed', order: 0, status: TaskStatus.completed),
      firstPending,
    ]);

    final firstResult = service.analyze(mission);
    final secondResult = service.analyze(mission);

    expect(firstResult.nextRecommendedTask, same(firstPending));
    expect(secondResult.nextRecommendedTask, same(firstPending));
    expect(firstResult.hasIncompleteTasks, isTrue);
    expect(firstResult.requiresUserAction, isTrue);
    expect(firstResult.isCompleted, isFalse);
  });

  test('recommends an in-progress task at the next workflow position', () {
    final inProgress = _task(
      'task-in-progress',
      order: 1,
      status: TaskStatus.inProgress,
    );
    final mission = _mission(<MissionTask>[
      _task('task-completed', order: 0, status: TaskStatus.completed),
      _task('task-pending', order: 2, status: TaskStatus.pending),
      inProgress,
    ]);

    final result = service.analyze(mission);

    expect(result.nextRecommendedTask, same(inProgress));
    expect(result.hasIncompleteTasks, isTrue);
    expect(result.requiresUserAction, isTrue);
    expect(result.isCompleted, isFalse);
  });

  test('skipped and failed tasks are incomplete but not recommended', () {
    final pending = _task('task-pending', order: 2, status: TaskStatus.pending);
    final mission = _mission(<MissionTask>[
      _task('task-skipped', order: 0, status: TaskStatus.skipped),
      _task('task-failed', order: 1, status: TaskStatus.failed),
      pending,
    ]);
    final blockedMission = _mission(<MissionTask>[
      _task('only-skipped', order: 0, status: TaskStatus.skipped),
      _task('only-failed', order: 1, status: TaskStatus.failed),
    ]);

    final result = service.analyze(mission);
    final blockedResult = service.analyze(blockedMission);

    expect(result.nextRecommendedTask, same(pending));
    expect(result.hasIncompleteTasks, isTrue);
    expect(result.requiresUserAction, isTrue);
    expect(result.isCompleted, isFalse);
    expect(blockedResult.nextRecommendedTask, isNull);
    expect(blockedResult.hasIncompleteTasks, isTrue);
    expect(blockedResult.requiresUserAction, isTrue);
    expect(blockedResult.isCompleted, isFalse);
  });

  test('analysis does not mutate tasks, statuses, or mission progress', () {
    final tasks = <MissionTask>[
      _task('task-second', order: 1, status: TaskStatus.pending),
      _task('task-first', order: 0, status: TaskStatus.completed),
    ];
    final mission = _mission(tasks);
    final originalTaskIds = tasks.map((task) => task.id).toList();
    final originalStatuses = tasks.map((task) => task.status).toList();
    final originalOrders = tasks.map((task) => task.order).toList();
    final originalProgress = mission.taskProgress.percentage;

    final result = service.analyze(mission);

    expect(mission.tasks, same(tasks));
    expect(tasks.map((task) => task.id), originalTaskIds);
    expect(tasks.map((task) => task.status), originalStatuses);
    expect(tasks.map((task) => task.order), originalOrders);
    expect(mission.taskProgress.percentage, originalProgress);
    expect(result.nextRecommendedTask, same(tasks.first));
  });
}

Mission _mission(List<MissionTask> tasks) {
  final timestamp = DateTime.utc(2026, 7, 1, 9);

  return Mission(
    id: 'mission-intelligence',
    title: 'Mission intelligence',
    goal: 'Recommend the next user action',
    category: MissionCategory.productivity,
    status: MissionStatus.active,
    createdAt: timestamp,
    updatedAt: timestamp,
    currentTaskIndex: 0,
    progressPercent: 73,
    tasks: tasks,
  );
}

MissionTask _task(String id, {required int order, required TaskStatus status}) {
  return MissionTask(
    id: id,
    missionId: 'mission-intelligence',
    title: 'Task $id',
    description: 'Evaluate $id',
    order: order,
    status: status,
    taskType: 'test',
    createdAt: DateTime.utc(2026, 7, 1, 10),
    completedAt: status == TaskStatus.completed
        ? DateTime.utc(2026, 7, 1, 11)
        : null,
  );
}
