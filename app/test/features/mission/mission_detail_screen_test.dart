import 'dart:async';

import 'package:aiorbit/features/mission/controllers/mission_controller.dart';
import 'package:aiorbit/features/mission/mission_detail_screen.dart';
import 'package:aiorbit/features/mission/models/execution_status.dart';
import 'package:aiorbit/features/mission/models/mission.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:aiorbit/features/mission/models/mission_execution.dart';
import 'package:aiorbit/features/mission/models/mission_status.dart';
import 'package:aiorbit/features/mission/models/mission_task.dart';
import 'package:aiorbit/features/mission/models/mission_task_execution.dart';
import 'package:aiorbit/features/mission/models/task_status.dart';
import 'package:aiorbit/features/mission/providers/mission_execution_provider.dart';
import 'package:aiorbit/features/mission/providers/mission_provider.dart';
import 'package:aiorbit/features/mission/providers/mission_task_execution_provider.dart';
import 'package:aiorbit/features/mission/services/memory_mission_repository.dart';
import 'package:aiorbit/features/mission/services/mission_task_executor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Mission summary preserves mission detail content', (
    tester,
  ) async {
    final mission = _mission(<MissionTask>[
      _task('completed', TaskStatus.completed, 0),
      _task('pending', TaskStatus.pending, 1),
    ]);
    final repository = MemoryMissionRepository();
    final controller = MissionController(repository: repository);

    await repository.saveMission(mission);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MissionDetailScreen(
            mission: mission,
            missionController: controller,
          ),
        ),
      ),
    );

    expect(find.text('Mission'), findsWidgets);
    expect(find.text('Complete the mission'), findsOneWidget);
    expect(find.text('Productivity'), findsOneWidget);
    expect(find.text('Task progress'), findsOneWidget);
    expect(find.text('Mission Completed'), findsNothing);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('1 / 2 Tasks Completed'), findsOneWidget);
    expect(find.text('Mission Execution'), findsOneWidget);
    expect(find.text('Mission Timeline'), findsOneWidget);
    expect(find.text('Workflow'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('task-status-pending')),
      findsOneWidget,
    );

    final indicators = tester.widgetList<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );

    expect(indicators.any((indicator) => indicator.value == 0.5), isTrue);
  });

  testWidgets('task status changes rebuild task progress and keep content', (
    tester,
  ) async {
    final mission = _mission(<MissionTask>[
      _task('research', TaskStatus.pending, 0),
    ]);
    final repository = MemoryMissionRepository();
    final controller = MissionController(repository: repository);

    await repository.saveMission(mission);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MissionDetailScreen(
            mission: mission,
            missionController: controller,
          ),
        ),
      ),
    );

    expect(find.text('Mission'), findsWidgets);
    expect(find.text('Complete the mission'), findsOneWidget);
    expect(find.text('Mission Execution'), findsOneWidget);
    expect(find.text('Workflow'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('0 / 1 Tasks Completed'), findsOneWidget);

    final statusControl = find.byKey(
      const ValueKey<String>('task-status-research'),
    );

    await tester.ensureVisible(statusControl);
    await tester.tap(statusControl);
    await tester.pumpAndSettle();
    await tester.tap(find.text('In Progress').last);
    await tester.pumpAndSettle();

    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);

    await tester.tap(statusControl);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed').last);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: statusControl, matching: find.text('Completed')),
      findsOneWidget,
    );
    expect(find.text('Mission Completed'), findsOneWidget);
    expect(find.text('All tasks completed successfully.'), findsOneWidget);
    expect(find.text('1 / 1 Tasks Completed'), findsOneWidget);
    expect(find.text('Task progress'), findsNothing);
    expect(find.text('Complete the mission'), findsOneWidget);
    expect(find.text('Mission Timeline'), findsOneWidget);
    expect(find.text('Mission Execution'), findsOneWidget);
    expect(find.text('Workflow'), findsOneWidget);
    expect(statusControl, findsOneWidget);

    final persistedMission = await repository.getMission(mission.id);
    expect(persistedMission?.tasks.single.status, TaskStatus.completed);

    await tester.tap(statusControl);
    await tester.pumpAndSettle();
    await tester.tap(find.text('In Progress').last);
    await tester.pumpAndSettle();

    expect(find.text('Mission Completed'), findsNothing);
    expect(find.text('Task progress'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('0 / 1 Tasks Completed'), findsOneWidget);
    expect(
      find.descendant(of: statusControl, matching: find.text('In Progress')),
      findsOneWidget,
    );

    final reopenedMission = await repository.getMission(mission.id);
    expect(reopenedMission?.tasks.single.status, TaskStatus.inProgress);
  });

  testWidgets('execution completion does not complete pending workflow tasks', (
    tester,
  ) async {
    final mission = _mission(<MissionTask>[
      _task('research', TaskStatus.pending, 0),
    ]);
    final repository = MemoryMissionRepository();
    final controller = MissionController(repository: repository);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await repository.saveMission(mission);

    final execution = container.read(missionExecutionProvider.notifier);
    execution.createExecution(executionId: 'execution', missionId: mission.id);
    execution.prepare();
    execution.start();
    execution.complete();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MissionDetailScreen(
            mission: mission,
            missionController: controller,
          ),
        ),
      ),
    );

    expect(find.text('Mission Completed'), findsNothing);
    expect(find.text('Task progress'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('0 / 1 Tasks Completed'), findsOneWidget);
    expect(find.text('100% executed'), findsOneWidget);
    expect(find.text('Execution Completed'), findsOneWidget);
  });

  testWidgets(
    'timeline shows mission dates and missing timestamp placeholders',
    (tester) async {
      final mission = _mission(
        <MissionTask>[_task('research', TaskStatus.pending, 0)],
        createdAt: DateTime(2026, 1, 2, 9, 30),
        updatedAt: DateTime(2026, 1, 3, 16, 45),
      );
      final repository = MemoryMissionRepository();
      final controller = MissionController(repository: repository);

      await repository.saveMission(mission);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MissionDetailScreen(
              mission: mission,
              missionController: controller,
            ),
          ),
        ),
      );

      expect(find.text('Mission Timeline'), findsOneWidget);
      expect(find.text('Created'), findsOneWidget);
      expect(find.text('Jan 2, 2026, 9:30 AM'), findsOneWidget);
      expect(find.text('Updated'), findsOneWidget);
      expect(find.text('Jan 3, 2026, 4:45 PM'), findsOneWidget);
      expect(find.text('Not started'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);

      expect(find.text('Complete the mission'), findsOneWidget);
      expect(find.text('Mission Execution'), findsOneWidget);
      expect(find.text('Workflow'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('task-status-research')),
        findsOneWidget,
      );
    },
  );

  testWidgets('only eligible tasks show Run Task', (tester) async {
    final mission = _mission(<MissionTask>[
      _task('pending', TaskStatus.pending, 0),
      _task('in-progress', TaskStatus.inProgress, 1),
      _task('completed', TaskStatus.completed, 2),
      _task('skipped', TaskStatus.skipped, 3),
      _task('failed', TaskStatus.failed, 4),
    ]);
    final repository = MemoryMissionRepository();
    final controller = MissionController(repository: repository);

    await repository.saveMission(mission);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MissionDetailScreen(
            mission: mission,
            missionController: controller,
          ),
        ),
      ),
    );

    expect(find.text('Run Task'), findsNWidgets(2));
    expect(find.text('Accept Result'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('run-task-pending')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('run-task-in-progress')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('run-task-completed')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('run-task-skipped')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey<String>('run-task-failed')), findsNothing);
  });

  testWidgets('Run Task shows loading and the successful output', (
    tester,
  ) async {
    final mission = _mission(<MissionTask>[
      _task('research', TaskStatus.pending, 0),
    ]);
    final repository = MemoryMissionRepository();
    final controller = MissionController(repository: repository);
    final executor = _ControllableMissionTaskExecutor();
    final container = _taskExecutionContainer(
      repository: repository,
      executor: executor,
    );
    addTearDown(container.dispose);

    await repository.saveMission(mission);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MissionDetailScreen(
            mission: mission,
            missionController: controller,
          ),
        ),
      ),
    );

    final runTask = find.byKey(const ValueKey<String>('run-task-research'));
    await tester.ensureVisible(runTask);
    await tester.tap(runTask);
    await tester.tap(runTask);
    await executor.waitForCalls(1);
    await tester.pump();

    expect(executor.callCount, 1);
    expect(find.text('Running…'), findsOneWidget);
    expect(find.text('Accept Result'), findsNothing);
    expect(tester.widget<OutlinedButton>(runTask).onPressed, isNull);
    expect(container.read(missionExecutionProvider), isNull);

    executor.complete(
      0,
      _taskExecutionResult(
        task: mission.tasks.single,
        status: ExecutionStatus.completed,
        outputText: 'Research execution output',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Task execution completed'), findsOneWidget);
    expect(find.text('Research execution output'), findsOneWidget);
    expect(find.text('Run Task'), findsOneWidget);
    expect(find.text('Accept Result'), findsOneWidget);
    expect(container.read(missionExecutionProvider), isNull);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('0 / 1 Tasks Completed'), findsOneWidget);
    expect(find.text('Mission Execution'), findsOneWidget);
    expect(find.text('Mission Timeline'), findsOneWidget);
    expect(find.text('Workflow'), findsOneWidget);

    final persistedMission = await repository.getMission(mission.id);
    expect(persistedMission?.tasks.single.status, TaskStatus.pending);
    expect(persistedMission?.taskProgress.percentage, 0);

    final acceptResult = find.byKey(
      const ValueKey<String>('accept-task-result-research'),
    );
    await tester.ensureVisible(acceptResult);
    await tester.tap(acceptResult);
    await tester.tap(acceptResult);
    await tester.pumpAndSettle();

    expect(find.text('Mission Completed'), findsOneWidget);
    expect(find.text('Task completed'), findsOneWidget);
    expect(find.text('Research execution output'), findsOneWidget);
    expect(find.text('Accept Result'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('run-task-research')),
      findsNothing,
    );
    expect(find.text('1 / 1 Tasks Completed'), findsOneWidget);
    expect(container.read(missionExecutionProvider), isNull);

    final acceptedMission = await repository.getMission(mission.id);
    expect(acceptedMission?.tasks.single.status, TaskStatus.completed);
    expect(acceptedMission?.tasks.single.completedAt, isNotNull);
    expect(acceptedMission?.taskProgress.percentage, 100);

    final statusControl = find.byKey(
      const ValueKey<String>('task-status-research'),
    );
    await tester.ensureVisible(statusControl);
    await tester.tap(statusControl);
    await tester.pumpAndSettle();
    await tester.tap(find.text('In Progress').last);
    await tester.pumpAndSettle();

    expect(find.text('Mission Completed'), findsNothing);
    expect(find.text('Task progress'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('Research execution output'), findsOneWidget);
    expect(find.text('Task completed'), findsNothing);
    expect(find.text('Accept Result'), findsOneWidget);
    expect(find.text('Run Task'), findsOneWidget);
    expect(container.read(missionExecutionProvider), isNull);

    final reopenedMission = await repository.getMission(mission.id);
    expect(reopenedMission?.tasks.single.status, TaskStatus.inProgress);
    expect(reopenedMission?.tasks.single.completedAt, isNull);
    expect(reopenedMission?.taskProgress.percentage, 0);
  });

  testWidgets('failed task execution can be retried safely', (tester) async {
    final mission = _mission(<MissionTask>[
      _task('research', TaskStatus.pending, 0),
    ]);
    final repository = MemoryMissionRepository();
    final controller = MissionController(repository: repository);
    final executor = _ControllableMissionTaskExecutor();
    final container = _taskExecutionContainer(
      repository: repository,
      executor: executor,
    );
    addTearDown(container.dispose);

    await repository.saveMission(mission);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MissionDetailScreen(
            mission: mission,
            missionController: controller,
          ),
        ),
      ),
    );

    final runTask = find.byKey(const ValueKey<String>('run-task-research'));
    await tester.ensureVisible(runTask);
    await tester.tap(runTask);
    await tester.tap(runTask);
    await executor.waitForCalls(1);
    await tester.pump();
    expect(executor.callCount, 1);
    expect(find.text('Accept Result'), findsNothing);
    executor.fail(0, StateError('provider-specific detail'));
    await tester.pumpAndSettle();

    expect(find.text('Task execution failed'), findsOneWidget);
    expect(
      find.text('Unable to complete this task. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('provider-specific detail'), findsNothing);
    expect(find.text('Retry Task'), findsOneWidget);
    expect(find.text('Accept Result'), findsNothing);

    await tester.tap(runTask);
    await tester.tap(runTask);
    await executor.waitForCalls(2);
    await tester.pump();

    expect(executor.callCount, 2);
    expect(find.text('Running…'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(runTask).onPressed, isNull);

    executor.complete(
      1,
      _taskExecutionResult(
        task: mission.tasks.single,
        status: ExecutionStatus.completed,
        outputText: 'Retry succeeded',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Task execution failed'), findsNothing);
    expect(find.text('Retry succeeded'), findsOneWidget);
    expect(find.text('Accept Result'), findsOneWidget);
    expect(container.read(missionExecutionProvider), isNull);
    expect(find.text('0%'), findsOneWidget);

    final acceptResult = find.byKey(
      const ValueKey<String>('accept-task-result-research'),
    );
    await tester.ensureVisible(acceptResult);
    await tester.tap(acceptResult);
    await tester.tap(acceptResult);
    await tester.pumpAndSettle();

    expect(find.text('Mission Completed'), findsOneWidget);
    expect(find.text('Task completed'), findsOneWidget);
    expect(find.text('Accept Result'), findsNothing);
    expect(find.text('1 / 1 Tasks Completed'), findsOneWidget);
    expect(
      (await repository.getMission(mission.id))?.tasks.single.status,
      TaskStatus.completed,
    );
    expect(container.read(missionExecutionProvider), isNull);
  });

  testWidgets('manual completion during a run is not overwritten', (
    tester,
  ) async {
    final mission = _mission(<MissionTask>[
      _task('research', TaskStatus.inProgress, 0),
    ]);
    final repository = MemoryMissionRepository();
    final controller = MissionController(repository: repository);
    final executor = _ControllableMissionTaskExecutor();
    final container = _taskExecutionContainer(
      repository: repository,
      executor: executor,
    );
    addTearDown(container.dispose);

    await repository.saveMission(mission);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MissionDetailScreen(
            mission: mission,
            missionController: controller,
          ),
        ),
      ),
    );

    final runTask = find.byKey(const ValueKey<String>('run-task-research'));
    await tester.ensureVisible(runTask);
    await tester.tap(runTask);
    await executor.waitForCalls(1);
    await tester.pump();

    final statusControl = find.byKey(
      const ValueKey<String>('task-status-research'),
    );
    await tester.ensureVisible(statusControl);
    tester.widget<PopupMenuButton<TaskStatus>>(statusControl).onSelected!(
      TaskStatus.completed,
    );
    await tester.pump(const Duration(milliseconds: 1));

    executor.complete(
      0,
      _taskExecutionResult(
        task: mission.tasks.single,
        status: ExecutionStatus.completed,
        outputText: 'Late execution output',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mission Completed'), findsOneWidget);
    expect(find.text('Late execution output'), findsOneWidget);
    expect(find.text('Task completed'), findsOneWidget);
    expect(find.text('Accept Result'), findsNothing);
    expect(
      (await repository.getMission(mission.id))?.tasks.single.status,
      TaskStatus.completed,
    );
    expect(container.read(missionExecutionProvider), isNull);
  });

  testWidgets('navigating away during a run is lifecycle-safe', (tester) async {
    final mission = _mission(<MissionTask>[
      _task('research', TaskStatus.pending, 0),
    ]);
    final repository = MemoryMissionRepository();
    final controller = MissionController(repository: repository);
    final executor = _ControllableMissionTaskExecutor();
    final container = _taskExecutionContainer(
      repository: repository,
      executor: executor,
    );
    addTearDown(container.dispose);

    await repository.saveMission(mission);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MissionDetailScreen(
            mission: mission,
            missionController: controller,
          ),
        ),
      ),
    );

    final runTask = find.byKey(const ValueKey<String>('run-task-research'));
    await tester.ensureVisible(runTask);
    await tester.tap(runTask);
    await executor.waitForCalls(1);
    await tester.pump();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    await tester.pump();

    executor.complete(
      0,
      _taskExecutionResult(
        task: mission.tasks.single,
        status: ExecutionStatus.completed,
        outputText: 'Background result',
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      container
          .read(missionTaskExecutionProvider.notifier)
          .executionFor(missionId: mission.id, taskId: 'research')
          ?.status,
      ExecutionStatus.completed,
    );
    expect(
      (await repository.getMission(mission.id))?.tasks.single.status,
      TaskStatus.pending,
    );
    expect(container.read(missionExecutionProvider), isNull);
  });

  testWidgets('multiple task records render under their matching tasks', (
    tester,
  ) async {
    final mission = _mission(<MissionTask>[
      _task('first', TaskStatus.pending, 0),
      _task('second', TaskStatus.inProgress, 1),
    ]);
    final repository = MemoryMissionRepository();
    final controller = MissionController(repository: repository);
    final container = _taskExecutionContainer(
      repository: repository,
      executor: const _ImmediateMissionTaskExecutor(),
    );
    addTearDown(container.dispose);

    await repository.saveMission(mission);

    final notifier = container.read(missionTaskExecutionProvider.notifier);
    await notifier.executeTask(missionId: mission.id, taskId: 'first');
    await notifier.executeTask(missionId: mission.id, taskId: 'second');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MissionDetailScreen(
            mission: mission,
            missionController: controller,
          ),
        ),
      ),
    );

    final firstTask = find.byKey(const ValueKey<String>('mission-task-first'));
    final secondTask = find.byKey(
      const ValueKey<String>('mission-task-second'),
    );

    expect(
      find.descendant(of: firstTask, matching: find.text('Output for first')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: secondTask, matching: find.text('Output for second')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: firstTask, matching: find.text('Accept Result')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: secondTask, matching: find.text('Accept Result')),
      findsOneWidget,
    );
    expect(container.read(missionTaskExecutionProvider), hasLength(2));
    expect(container.read(missionExecutionProvider), isNull);
    expect(find.text('Mission Execution'), findsOneWidget);
    expect(find.text('Mission Timeline'), findsOneWidget);
    expect(find.text('Workflow'), findsOneWidget);
  });

  testWidgets('empty workflow guides the user back to the existing route', (
    tester,
  ) async {
    final mission = _mission(const <MissionTask>[]);
    final repository = MemoryMissionRepository();
    final controller = MissionController(repository: repository);

    await repository.saveMission(mission);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MissionDetailScreen(
                            mission: mission,
                            missionController: controller,
                          ),
                        ),
                      );
                    },
                    child: const Text('Open mission'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open mission'));
    await tester.pumpAndSettle();

    expect(find.text('This mission needs a workflow'), findsOneWidget);
    expect(
      find.text(
        'Return to Chat and tell Ovexiq what you want to accomplish in more '
        'detail.',
      ),
      findsOneWidget,
    );
    expect(find.text('Back to Chat'), findsOneWidget);

    final backToChatButton = find.text('Back to Chat');
    await tester.ensureVisible(backToChatButton);
    await tester.tap(backToChatButton);
    await tester.pumpAndSettle();

    expect(find.text('Open mission'), findsOneWidget);
  });
}

Mission _mission(
  List<MissionTask> tasks, {
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final missionCreatedAt = createdAt ?? DateTime(2026);

  return Mission(
    id: 'mission',
    title: 'Mission',
    goal: 'Complete the mission',
    category: MissionCategory.productivity,
    status: MissionStatus.active,
    createdAt: missionCreatedAt,
    updatedAt: updatedAt ?? missionCreatedAt,
    currentTaskIndex: 0,
    progressPercent: 99,
    tasks: tasks,
  );
}

MissionTask _task(String id, TaskStatus status, int order) {
  return MissionTask(
    id: id,
    missionId: 'mission',
    title: id,
    description: id,
    order: order,
    status: status,
    taskType: 'test',
    createdAt: DateTime(2026),
  );
}

ProviderContainer _taskExecutionContainer({
  required MemoryMissionRepository repository,
  required MissionTaskExecutor executor,
}) {
  return ProviderContainer(
    overrides: <Override>[
      missionRepositoryProvider.overrideWithValue(repository),
      missionTaskExecutorProvider.overrideWithValue(executor),
      missionTaskExecutionClockProvider.overrideWithValue(
        () => DateTime(2026, 2, 4, 10),
      ),
    ],
  );
}

class _ControllableMissionTaskExecutor implements MissionTaskExecutor {
  final _calls = <Completer<MissionTaskExecution>>[];

  int get callCount => _calls.length;

  @override
  Future<MissionTaskExecution> execute({
    required Mission mission,
    required MissionTask task,
  }) {
    final call = Completer<MissionTaskExecution>();
    _calls.add(call);
    return call.future;
  }

  Future<void> waitForCalls(int count) async {
    while (_calls.length < count) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void complete(int index, MissionTaskExecution result) {
    _calls[index].complete(result);
  }

  void fail(int index, Object error) {
    _calls[index].completeError(error);
  }
}

class _ImmediateMissionTaskExecutor implements MissionTaskExecutor {
  const _ImmediateMissionTaskExecutor();

  @override
  Future<MissionTaskExecution> execute({
    required Mission mission,
    required MissionTask task,
  }) async {
    return _taskExecutionResult(
      task: task,
      status: ExecutionStatus.completed,
      outputText: 'Output for ${task.id}',
    );
  }
}

MissionTaskExecution _taskExecutionResult({
  required MissionTask task,
  required ExecutionStatus status,
  String? outputText,
}) {
  return MissionTaskExecution(
    execution: MissionExecution(
      id: 'task-execution-${task.id}',
      missionId: task.missionId,
      status: status,
      progress: status == ExecutionStatus.completed ? 1 : 0,
      startedAt: DateTime(2026, 2, 4, 10),
      finishedAt: DateTime(2026, 2, 4, 10, 2),
      currentTaskId: task.id,
    ),
    outputText: outputText,
    failureMessage: status == ExecutionStatus.failed
        ? 'Unable to complete this task. Please try again.'
        : null,
  );
}
