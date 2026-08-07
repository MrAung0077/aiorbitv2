import 'package:aiorbit/features/mission/mission_final_results_card.dart';
import 'package:aiorbit/features/mission/mission_task_output_screen.dart';
import 'package:aiorbit/features/mission/models/execution_status.dart';
import 'package:aiorbit/features/mission/models/mission_execution.dart';
import 'package:aiorbit/features/mission/models/mission_task.dart';
import 'package:aiorbit/features/mission/models/mission_task_execution.dart';
import 'package:aiorbit/features/mission/models/task_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows final results and opens a completed output', (
    tester,
  ) async {
    final task = MissionTask(
      id: 'research',
      missionId: 'mission',
      title: 'Research competitors',
      description: 'Research competitors',
      order: 0,
      status: TaskStatus.completed,
      taskType: 'research',
      createdAt: DateTime(2026),
    );

    final taskExecution = MissionTaskExecution(
      execution: MissionExecution(
        id: 'execution-research',
        missionId: 'mission',
        status: ExecutionStatus.completed,
        progress: 1,
        startedAt: DateTime(2026),
        finishedAt: DateTime(2026, 1, 1, 0, 1),
        currentTaskId: task.id,
      ),
      outputText: '  Finished competitor research  ',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MissionFinalResultsCard(
            results: [
              MissionFinalResult(
                task: task,
                execution: taskExecution,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Final Results'), findsOneWidget);
    expect(find.text('1 finished result is ready.'), findsOneWidget);
    expect(find.text('Research competitors'), findsOneWidget);

    final resultTile = find.byKey(
      const ValueKey<String>('open-final-result-research'),
    );

    await tester.tap(resultTile);
    await tester.pumpAndSettle();

    expect(find.byType(MissionTaskOutputScreen), findsOneWidget);
    expect(find.text('Task Output'), findsOneWidget);
    expect(find.text('Research competitors'), findsOneWidget);
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      'Finished competitor research',
    );
  });

  testWidgets('empty final results render nothing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MissionFinalResultsCard(
            results: [],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('mission-final-results')),
      findsNothing,
    );
    expect(find.text('Final Results'), findsNothing);
  });
}