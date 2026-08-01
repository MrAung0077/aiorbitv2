import 'package:aiorbit/features/mission/data/mappers/mission_record_mapper.dart';
import 'package:aiorbit/features/mission/data/models/mission_record.dart';
import 'package:aiorbit/features/mission/data/models/mission_task_record.dart';
import 'package:aiorbit/features/mission/models/mission.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:aiorbit/features/mission/models/mission_status.dart';
import 'package:aiorbit/features/mission/models/mission_task.dart';
import 'package:aiorbit/features/mission/models/task_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = MissionRecordMapper();

  test('maps a multi-task mission to a record and back', () {
    final createdAt = DateTime.utc(2026, 3, 1, 9);
    final updatedAt = DateTime.utc(2026, 3, 2, 14, 30);
    final completedAt = DateTime.utc(2026, 3, 2, 12);
    final mission = Mission(
      id: 'mission-1',
      title: 'Launch campaign',
      goal: 'Prepare and publish a launch campaign',
      category: MissionCategory.marketing,
      status: MissionStatus.active,
      createdAt: createdAt,
      updatedAt: updatedAt,
      currentTaskIndex: 1,
      progressPercent: 50,
      conversationId: 'conversation-1',
      userContext: 'Target existing customers',
      tasks: <MissionTask>[
        MissionTask(
          id: 'task-1',
          missionId: 'mission-1',
          title: 'Research audience',
          description: 'Review existing audience insights.',
          order: 0,
          status: TaskStatus.inProgress,
          taskType: 'research',
          recommendedProvider: 'provider-a',
          inputContext: 'Use the current customer segments.',
          createdAt: createdAt,
        ),
        MissionTask(
          id: 'task-2',
          missionId: 'mission-1',
          title: 'Draft campaign',
          description: 'Draft the campaign assets.',
          order: 1,
          status: TaskStatus.completed,
          taskType: 'writing',
          createdAt: createdAt.add(const Duration(hours: 1)),
          completedAt: completedAt,
        ),
      ],
    );

    final record = mapper.toRecord(mission, databaseId: 42);
    final restored = mapper.toDomain(record);

    expect(record.id, 42);
    expect(record.missionId, mission.id);
    expect(record.conversationId, mission.conversationId);
    expect(record.title, mission.title);
    expect(record.goal, mission.goal);
    expect(record.category, mission.category.name);
    expect(record.status, mission.status.name);
    expect(record.createdAt, createdAt);
    expect(record.updatedAt, updatedAt);
    expect(record.currentTaskIndex, 1);
    expect(record.userContext, mission.userContext);
    expect(record.tasks, hasLength(2));
    expect(record.tasks.first.status, TaskStatus.inProgress.name);
    expect(record.tasks.last.status, TaskStatus.completed.name);
    expect(record.tasks.last.completedAt, completedAt);

    expect(restored.id, mission.id);
    expect(restored.conversationId, mission.conversationId);
    expect(restored.title, mission.title);
    expect(restored.goal, mission.goal);
    expect(restored.category, mission.category);
    expect(restored.status, mission.status);
    expect(restored.createdAt, createdAt);
    expect(restored.updatedAt, updatedAt);
    expect(restored.currentTaskIndex, mission.currentTaskIndex);
    expect(restored.userContext, mission.userContext);
    expect(restored.tasks, hasLength(2));
    expect(restored.tasks.first.id, 'task-1');
    expect(restored.tasks.first.missionId, mission.id);
    expect(restored.tasks.first.recommendedProvider, 'provider-a');
    expect(
      restored.tasks.first.inputContext,
      'Use the current customer segments.',
    );
    expect(restored.tasks.last.status, TaskStatus.completed);
    expect(restored.tasks.last.completedAt, completedAt);
    expect(restored.taskProgress.completedTasks, 1);
    expect(restored.taskProgress.totalTasks, 2);
    expect(restored.taskProgress.percentage, 50);
    expect(restored.progressPercent, 50);
  });

  test('handles optional fields without inventing values', () {
    final createdAt = DateTime.utc(2026, 3, 3);
    final mission = Mission(
      id: 'mission-optional',
      title: 'Optional fields',
      goal: 'Verify nullable values',
      category: MissionCategory.custom,
      status: MissionStatus.draft,
      createdAt: createdAt,
      updatedAt: createdAt,
      currentTaskIndex: 0,
      progressPercent: 0,
      tasks: <MissionTask>[
        MissionTask(
          id: 'task-optional',
          missionId: 'mission-optional',
          title: 'Optional task',
          description: 'Keep optional values empty.',
          order: 0,
          status: TaskStatus.pending,
          taskType: 'planning',
          createdAt: createdAt,
        ),
      ],
    );

    final restored = mapper.toDomain(mapper.toRecord(mission));

    expect(restored.conversationId, isNull);
    expect(restored.userContext, isNull);
    expect(restored.tasks.single.recommendedProvider, isNull);
    expect(restored.tasks.single.inputContext, isNull);
    expect(restored.tasks.single.completedAt, isNull);
    expect(restored.tasks.single.output, isNull);
  });

  test('derived progress and task execution output are not restored', () {
    final createdAt = DateTime.utc(2026, 3, 4);
    final mission = Mission(
      id: 'mission-derived',
      title: 'Derived values',
      goal: 'Recalculate progress',
      category: MissionCategory.productivity,
      status: MissionStatus.active,
      createdAt: createdAt,
      updatedAt: createdAt,
      currentTaskIndex: 0,
      progressPercent: 99,
      tasks: <MissionTask>[
        MissionTask(
          id: 'task-complete',
          missionId: 'mission-derived',
          title: 'Complete task',
          description: 'Already complete.',
          order: 0,
          status: TaskStatus.completed,
          taskType: 'test',
          output: 'Session-only execution output',
          createdAt: createdAt,
          completedAt: createdAt,
        ),
        MissionTask(
          id: 'task-pending',
          missionId: 'mission-derived',
          title: 'Pending task',
          description: 'Still pending.',
          order: 1,
          status: TaskStatus.pending,
          taskType: 'test',
          createdAt: createdAt,
        ),
      ],
    );

    final restored = mapper.toDomain(mapper.toRecord(mission));

    expect(restored.taskProgress.completedTasks, 1);
    expect(restored.taskProgress.totalTasks, 2);
    expect(restored.taskProgress.percentage, 50);
    expect(restored.progressPercent, 50);
    expect(restored.tasks.first.output, isNull);
  });

  test('unknown stored enum names use safe fallbacks', () {
    final timestamp = DateTime.utc(2026, 3, 5);
    final record = MissionRecord()
      ..missionId = 'mission-fallback'
      ..title = 'Fallback mission'
      ..goal = 'Handle future enum values safely'
      ..category = 'futureCategory'
      ..status = 'futureMissionStatus'
      ..createdAt = timestamp
      ..updatedAt = timestamp
      ..tasks = <MissionTaskRecord>[
        MissionTaskRecord()
          ..taskId = 'task-fallback'
          ..title = 'Fallback task'
          ..description = 'Use a safe task status.'
          ..status = 'futureTaskStatus'
          ..taskType = 'test'
          ..createdAt = timestamp,
      ];

    final restored = mapper.toDomain(record);

    expect(restored.category, MissionCategory.custom);
    expect(restored.status, MissionStatus.draft);
    expect(restored.tasks.single.status, TaskStatus.pending);
    expect(restored.tasks.single.missionId, record.missionId);
  });

  test('normalizes corrupted task metadata and recalculates progress', () {
    final createdAt = DateTime.utc(2026, 5, 2, 9);
    final invalidUpdatedAt = createdAt.subtract(const Duration(days: 1));
    final inconsistentCompletedAt = createdAt.add(const Duration(hours: 1));
    final record = MissionRecord()
      ..missionId = ' mission-integrity '
      ..conversationId = '   '
      ..title = 'Integrity mission'
      ..goal = 'Restore corrupted task metadata safely'
      ..category = MissionCategory.productivity.name
      ..status = MissionStatus.active.name
      ..createdAt = createdAt
      ..updatedAt = invalidUpdatedAt
      ..currentTaskIndex = 99
      ..tasks = <MissionTaskRecord>[
        MissionTaskRecord()
          ..taskId = '   '
          ..order = 0
          ..status = TaskStatus.pending.name
          ..createdAt = createdAt,
        MissionTaskRecord()
          ..taskId = 'task-late'
          ..missionId = ''
          ..title = 'Later task'
          ..description = 'Keep source order for duplicate order values.'
          ..order = 5
          ..status = TaskStatus.pending.name
          ..taskType = 'test'
          ..createdAt = createdAt
          ..completedAt = inconsistentCompletedAt,
        MissionTaskRecord()
          ..taskId = 'task-first'
          ..missionId = 'wrong-mission'
          ..title = 'First task'
          ..description = 'Sort by persisted task order.'
          ..order = -2
          ..status = TaskStatus.completed.name
          ..taskType = 'test'
          ..createdAt = createdAt,
        MissionTaskRecord()
          ..taskId = 'task-tie'
          ..title = 'Tied task'
          ..description = 'Unknown status falls back safely.'
          ..order = 5
          ..status = 'futureStatus'
          ..taskType = 'test'
          ..createdAt = createdAt
          ..completedAt = inconsistentCompletedAt,
        MissionTaskRecord()
          ..taskId = 'task-late'
          ..title = 'Duplicate task identifier'
          ..description = 'Do not restore an ambiguous duplicate task.'
          ..order = 6
          ..status = TaskStatus.completed.name
          ..taskType = 'test'
          ..createdAt = createdAt
          ..completedAt = inconsistentCompletedAt,
      ];

    final restored = mapper.toDomain(record);

    expect(restored.id, 'mission-integrity');
    expect(restored.conversationId, isNull);
    expect(restored.updatedAt, createdAt);
    expect(restored.currentTaskIndex, 2);
    expect(restored.tasks.map((task) => task.id), <String>[
      'task-first',
      'task-late',
      'task-tie',
    ]);
    expect(restored.tasks.map((task) => task.order), <int>[0, 1, 2]);
    expect(
      restored.tasks.every((task) => task.missionId == restored.id),
      isTrue,
    );
    expect(restored.tasks.first.status, TaskStatus.completed);
    expect(restored.tasks.first.completedAt, isNull);
    expect(restored.tasks[1].completedAt, isNull);
    expect(restored.tasks.last.status, TaskStatus.pending);
    expect(restored.tasks.last.completedAt, isNull);
    expect(restored.taskProgress.completedTasks, 1);
    expect(restored.taskProgress.totalTasks, 3);
    expect(restored.taskProgress.percentage, 33);
    expect(restored.progressPercent, 33);
    expect(restored.tasks.clear, throwsUnsupportedError);
  });

  test('empty task collections normalize index and progress to zero', () {
    final timestamp = DateTime.utc(2026, 5, 3);
    final record = MissionRecord()
      ..missionId = 'mission-empty-tasks'
      ..title = 'Empty workflow'
      ..goal = 'Remain safe without tasks'
      ..createdAt = timestamp
      ..updatedAt = timestamp
      ..currentTaskIndex = -4
      ..tasks = <MissionTaskRecord>[];

    final restored = mapper.toDomain(record);

    expect(restored.tasks, isEmpty);
    expect(restored.currentTaskIndex, 0);
    expect(restored.taskProgress.percentage, 0);
    expect(restored.progressPercent, 0);
  });

  test('rejects blank mission and task identifiers on writes', () {
    final timestamp = DateTime.utc(2026, 5, 4);
    final blankMissionRecord = MissionRecord()
      ..missionId = '   '
      ..createdAt = timestamp
      ..updatedAt = timestamp;
    final blankMission = Mission(
      id: '   ',
      title: 'Invalid mission',
      goal: 'Reject invalid identity',
      category: MissionCategory.custom,
      status: MissionStatus.draft,
      createdAt: timestamp,
      updatedAt: timestamp,
      currentTaskIndex: 0,
      progressPercent: 0,
      tasks: const <MissionTask>[],
    );
    final blankTaskMission = Mission(
      id: 'valid-mission',
      title: 'Invalid task',
      goal: 'Reject invalid task identity',
      category: MissionCategory.custom,
      status: MissionStatus.draft,
      createdAt: timestamp,
      updatedAt: timestamp,
      currentTaskIndex: 0,
      progressPercent: 0,
      tasks: <MissionTask>[
        MissionTask(
          id: '  ',
          missionId: 'valid-mission',
          title: 'Invalid task',
          description: 'Missing task ID',
          order: 0,
          status: TaskStatus.pending,
          taskType: 'test',
          createdAt: timestamp,
        ),
      ],
    );

    expect(() => mapper.toDomain(blankMissionRecord), throwsFormatException);
    expect(() => mapper.toRecord(blankMission), throwsArgumentError);
    expect(() => mapper.toRecord(blankTaskMission), throwsArgumentError);
  });
}
