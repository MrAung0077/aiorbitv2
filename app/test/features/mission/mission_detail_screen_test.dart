import 'package:aiorbit/features/mission/controllers/mission_controller.dart';
import 'package:aiorbit/features/mission/mission_detail_screen.dart';
import 'package:aiorbit/features/mission/models/mission.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:aiorbit/features/mission/models/mission_status.dart';
import 'package:aiorbit/features/mission/models/mission_task.dart';
import 'package:aiorbit/features/mission/models/task_status.dart';
import 'package:aiorbit/features/mission/providers/mission_execution_provider.dart';
import 'package:aiorbit/features/mission/services/memory_mission_repository.dart';
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
