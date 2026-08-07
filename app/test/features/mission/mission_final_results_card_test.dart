import 'package:aiorbit/features/mission/mission_final_results_card.dart';
import 'package:aiorbit/features/mission/mission_task_output_screen.dart';
import 'package:aiorbit/features/mission/models/execution_status.dart';
import 'package:aiorbit/features/mission/models/mission_execution.dart';
import 'package:aiorbit/features/mission/models/mission_task.dart';
import 'package:aiorbit/features/mission/models/mission_task_execution.dart';
import 'package:aiorbit/features/mission/models/task_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
            results: [MissionFinalResult(task: task, execution: taskExecution)],
          ),
        ),
      ),
    );

    expect(find.text('Final Results'), findsOneWidget);
    expect(find.text('1 finished result is ready.'), findsOneWidget);
    expect(find.text('Research competitors'), findsOneWidget);
    expect(find.text('Finished competitor research'), findsOneWidget);
    expect(find.text('Copy All Results'), findsOneWidget);

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

  testWidgets('copy all results copies task titles and trimmed outputs', (
    tester,
  ) async {
    final clipboardMessages = <MethodCall>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardMessages.add(call);
          }

          return null;
        });

    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final firstTask = MissionTask(
      id: 'research',
      missionId: 'mission',
      title: '  Research competitors  ',
      description: 'Research competitors',
      order: 0,
      status: TaskStatus.completed,
      taskType: 'research',
      createdAt: DateTime(2026),
    );

    final secondTask = MissionTask(
      id: 'caption',
      missionId: 'mission',
      title: 'Write launch caption',
      description: 'Write launch caption',
      order: 1,
      status: TaskStatus.completed,
      taskType: 'writing',
      createdAt: DateTime(2026),
    );

    final firstExecution = MissionTaskExecution(
      execution: MissionExecution(
        id: 'execution-research',
        missionId: 'mission',
        status: ExecutionStatus.completed,
        progress: 1,
        startedAt: DateTime(2026),
        finishedAt: DateTime(2026, 1, 1, 0, 1),
        currentTaskId: firstTask.id,
      ),
      outputText: '  Finished competitor research  ',
    );

    final secondExecution = MissionTaskExecution(
      execution: MissionExecution(
        id: 'execution-caption',
        missionId: 'mission',
        status: ExecutionStatus.completed,
        progress: 1,
        startedAt: DateTime(2026),
        finishedAt: DateTime(2026, 1, 1, 0, 2),
        currentTaskId: secondTask.id,
      ),
      outputText: '  Launch Ovexiq today.  ',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MissionFinalResultsCard(
            results: [
              MissionFinalResult(task: firstTask, execution: firstExecution),
              MissionFinalResult(task: secondTask, execution: secondExecution),
            ],
          ),
        ),
      ),
    );

    expect(find.text('2 finished results are ready.'), findsOneWidget);

    final copyAllButton = find.byKey(
      const ValueKey<String>('copy-all-final-results-button'),
    );

    expect(copyAllButton, findsOneWidget);

    await tester.tap(copyAllButton);
    await tester.pump();

    expect(clipboardMessages, hasLength(1));
    expect(clipboardMessages.single.arguments, <String, dynamic>{
      'text':
          'Research competitors\n\n'
          'Finished competitor research\n\n'
          '---\n\n'
          'Write launch caption\n\n'
          'Launch Ovexiq today.',
    });

    expect(find.text('All final results copied'), findsOneWidget);
  });

  testWidgets('empty final results render nothing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MissionFinalResultsCard(results: [])),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('mission-final-results')),
      findsNothing,
    );
    expect(find.text('Final Results'), findsNothing);
    expect(find.text('Copy All Results'), findsNothing);
  });
}
