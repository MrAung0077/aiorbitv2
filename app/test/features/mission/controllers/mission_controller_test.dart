import 'package:aiorbit/features/mission/controllers/mission_controller.dart';
import 'package:aiorbit/features/mission/models/mission.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:aiorbit/features/mission/models/mission_status.dart';
import 'package:aiorbit/features/mission/models/mission_task.dart';
import 'package:aiorbit/features/mission/models/task_status.dart';
import 'package:aiorbit/features/mission/services/memory_mission_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('supported task status transitions are persisted', () async {
    final repository = MemoryMissionRepository();
    final controller = MissionController(repository: repository);

    await repository.saveMission(_mission(TaskStatus.pending));

    final inProgress = await controller.updateTaskStatus(
      missionId: 'mission',
      taskId: 'task',
      status: TaskStatus.inProgress,
    );

    expect(inProgress.tasks.single.status, TaskStatus.inProgress);
    expect(inProgress.tasks.single.completedAt, isNull);
    expect(inProgress.taskProgress.percentage, 0);

    final completed = await controller.updateTaskStatus(
      missionId: 'mission',
      taskId: 'task',
      status: TaskStatus.completed,
    );

    expect(completed.tasks.single.status, TaskStatus.completed);
    expect(completed.tasks.single.completedAt, isNotNull);
    expect(completed.taskProgress.percentage, 100);

    final reopened = await controller.updateTaskStatus(
      missionId: 'mission',
      taskId: 'task',
      status: TaskStatus.inProgress,
    );

    expect(reopened.tasks.single.status, TaskStatus.inProgress);
    expect(reopened.tasks.single.completedAt, isNull);
    expect(reopened.taskProgress.percentage, 0);

    final persisted = await repository.getMission('mission');
    expect(persisted?.tasks.single.status, TaskStatus.inProgress);
  });

  test('unsafe task status transitions are rejected without saving', () async {
    final repository = MemoryMissionRepository();
    final controller = MissionController(repository: repository);

    await repository.saveMission(_mission(TaskStatus.pending));

    await expectLater(
      controller.updateTaskStatus(
        missionId: 'mission',
        taskId: 'task',
        status: TaskStatus.completed,
      ),
      throwsStateError,
    );

    final persisted = await repository.getMission('mission');
    expect(persisted?.tasks.single.status, TaskStatus.pending);
  });

  test('conversation lookup returns the latest linked mission', () async {
    final repository = MemoryMissionRepository();
    final controller = MissionController(repository: repository);

    await repository.saveMission(
      _mission(
        TaskStatus.pending,
        id: 'older',
        conversationId: 'conversation',
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    await repository.saveMission(
      _mission(
        TaskStatus.completed,
        id: 'newer',
        conversationId: 'conversation',
        updatedAt: DateTime(2026, 1, 2),
      ),
    );
    await repository.saveMission(
      _mission(
        TaskStatus.completed,
        id: 'unrelated',
        conversationId: 'other-conversation',
        updatedAt: DateTime(2026, 1, 3),
      ),
    );

    final mission = await controller.getMissionForConversation('conversation');

    expect(mission?.id, 'newer');
  });
}

Mission _mission(
  TaskStatus status, {
  String id = 'mission',
  String? conversationId,
  DateTime? updatedAt,
}) {
  final createdAt = updatedAt ?? DateTime(2026);

  return Mission(
    id: id,
    title: 'Mission',
    goal: 'Complete the mission',
    category: MissionCategory.productivity,
    status: MissionStatus.active,
    createdAt: createdAt,
    updatedAt: createdAt,
    currentTaskIndex: 0,
    progressPercent: 0,
    tasks: <MissionTask>[
      MissionTask(
        id: 'task',
        missionId: id,
        title: 'Task',
        description: 'Complete the task',
        order: 0,
        status: status,
        taskType: 'test',
        createdAt: createdAt,
      ),
    ],
    conversationId: conversationId,
  );
}
