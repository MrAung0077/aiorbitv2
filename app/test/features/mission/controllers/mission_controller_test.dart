import 'package:aiorbit/features/mission/controllers/mission_controller.dart';
import 'package:aiorbit/features/mission/models/execution_status.dart';
import 'package:aiorbit/features/mission/models/mission.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:aiorbit/features/mission/models/mission_execution.dart';
import 'package:aiorbit/features/mission/models/mission_status.dart';
import 'package:aiorbit/features/mission/models/mission_task.dart';
import 'package:aiorbit/features/mission/models/mission_task_execution.dart';
import 'package:aiorbit/features/mission/models/task_status.dart';
import 'package:aiorbit/features/mission/services/memory_mission_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MissionTask copyWith can preserve, set, and clear output', () {
    final task = _mission(TaskStatus.pending).tasks.single;
    final withOutput = task.copyWith(output: 'Accepted output');

    expect(task.copyWith().output, isNull);
    expect(withOutput.output, 'Accepted output');
    expect(
      withOutput.copyWith(status: TaskStatus.inProgress).output,
      'Accepted output',
    );
    expect(withOutput.copyWith(output: null).output, isNull);
  });

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
    expect(completed.taskProgress.isComplete, isFalse);

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

  test(
    'accepting a pending task completes it through existing rules',
    () async {
      final repository = MemoryMissionRepository();
      final controller = MissionController(repository: repository);

      await repository.saveMission(_mission(TaskStatus.pending));

      final accepted = await controller.acceptTaskResult(
        missionId: 'mission',
        taskId: 'task',
        execution: _execution(outputText: '  Accepted task output  '),
      );

      expect(accepted.tasks.single.status, TaskStatus.completed);
      expect(accepted.tasks.single.completedAt, isNotNull);
      expect(accepted.tasks.single.output, 'Accepted task output');
      expect(accepted.taskProgress.percentage, 100);
      expect(accepted.taskProgress.isComplete, isTrue);

      final persisted = await repository.getMission('mission');
      expect(persisted?.tasks.single.status, TaskStatus.completed);
      expect(persisted?.tasks.single.completedAt, isNotNull);
      expect(persisted?.tasks.single.output, 'Accepted task output');
    },
  );

  test(
    'structured result reference is persisted when text is absent',
    () async {
      final repository = MemoryMissionRepository();
      final controller = MissionController(repository: repository);

      await repository.saveMission(_mission(TaskStatus.inProgress));

      final accepted = await controller.acceptTaskResult(
        missionId: 'mission',
        taskId: 'task',
        execution: _execution(
          outputText: '   ',
          structuredResultReference: '  result://mission/task  ',
        ),
      );

      expect(accepted.tasks.single.output, 'result://mission/task');
      expect(accepted.tasks.single.status, TaskStatus.completed);
    },
  );

  test(
    'non-completed execution is rejected without changing the task',
    () async {
      final repository = MemoryMissionRepository();
      final controller = MissionController(repository: repository);

      await repository.saveMission(_mission(TaskStatus.pending));

      await expectLater(
        controller.acceptTaskResult(
          missionId: 'mission',
          taskId: 'task',
          execution: _execution(
            status: ExecutionStatus.running,
            outputText: 'Incomplete output',
          ),
        ),
        throwsStateError,
      );

      final persisted = await repository.getMission('mission');
      expect(persisted?.tasks.single.status, TaskStatus.pending);
      expect(persisted?.tasks.single.output, isNull);
    },
  );

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

MissionTaskExecution _execution({
  ExecutionStatus status = ExecutionStatus.completed,
  String? outputText,
  String? structuredResultReference,
}) {
  return MissionTaskExecution(
    execution: MissionExecution(
      id: 'execution',
      missionId: 'mission',
      status: status,
      progress: status == ExecutionStatus.completed ? 1 : 0,
      startedAt: DateTime(2026, 1, 1, 10),
      finishedAt: status == ExecutionStatus.completed
          ? DateTime(2026, 1, 1, 10, 1)
          : null,
      currentTaskId: 'task',
    ),
    outputText: outputText,
    structuredResultReference: structuredResultReference,
  );
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
