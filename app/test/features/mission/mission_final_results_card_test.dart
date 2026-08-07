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
    final task = _task(
      id: 'research',
      title: 'Research competitors',
      order: 0,
    );

    final taskExecution = _execution(
      task: task,
      id: 'execution-research',
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
    expect(find.text('Finished competitor research'), findsOneWidget);
    expect(find.text('Copy All Results'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('open-final-result-research'),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(MissionTaskOutputScreen), findsOneWidget);
    expect(find.text('Task Output'), findsOneWidget);
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

    final firstTask = _task(
      id: 'research',
      title: '  Research competitors  ',
      order: 0,
    );

    final secondTask = _task(
      id: 'caption',
      title: 'Write launch caption',
      order: 1,
    );

    final firstExecution = _execution(
      task: firstTask,
      id: 'execution-research',
      outputText: '  Finished competitor research  ',
    );

    final secondExecution = _execution(
      task: secondTask,
      id: 'execution-caption',
      outputText: '  Launch Ovexiq today.  ',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MissionFinalResultsCard(
            results: [
              MissionFinalResult(
                task: firstTask,
                execution: firstExecution,
              ),
              MissionFinalResult(
                task: secondTask,
                execution: secondExecution,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('2 finished results are ready.'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('copy-all-final-results-button'),
      ),
    );

    await tester.pump();

    expect(clipboardMessages, hasLength(1));

    expect(
      clipboardMessages.single.arguments,
      <String, dynamic>{
        'text':
            'Research competitors\n\n'
            'Finished competitor research\n\n'
            '---\n\n'
            'Write launch caption\n\n'
            'Launch Ovexiq today.',
      },
    );

    expect(find.text('All final results copied'), findsOneWidget);
  });

  testWidgets('results without usable text are excluded', (tester) async {
    final usableTask = _task(
      id: 'usable',
      title: 'Usable result',
      order: 0,
    );

    final structuredTask = _task(
      id: 'structured',
      title: 'Structured result',
      order: 1,
    );

    final usableExecution = _execution(
      task: usableTask,
      id: 'execution-usable',
      outputText: 'Finished usable output',
    );

    final structuredExecution = MissionTaskExecution(
      execution: MissionExecution(
        id: 'execution-structured',
        missionId: 'mission',
        status: ExecutionStatus.completed,
        progress: 1,
        startedAt: DateTime(2026),
        finishedAt: DateTime(2026, 1, 1, 0, 2),
        currentTaskId: structuredTask.id,
      ),
      structuredResultReference: 'artifact://structured-result',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MissionFinalResultsCard(
            results: [
              MissionFinalResult(
                task: usableTask,
                execution: usableExecution,
              ),
              MissionFinalResult(
                task: structuredTask,
                execution: structuredExecution,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('1 finished result is ready.'), findsOneWidget);
    expect(find.text('Usable result'), findsOneWidget);
    expect(find.text('Finished usable output'), findsOneWidget);

    expect(find.text('Structured result'), findsNothing);
    expect(
      find.byKey(
        const ValueKey<String>('open-final-result-structured'),
      ),
      findsNothing,
    );
  });

  testWidgets('only non-text results render nothing', (tester) async {
    final task = _task(
      id: 'structured',
      title: 'Structured result',
      order: 0,
    );

    final execution = MissionTaskExecution(
      execution: MissionExecution(
        id: 'execution-structured',
        missionId: 'mission',
        status: ExecutionStatus.completed,
        progress: 1,
        startedAt: DateTime(2026),
        finishedAt: DateTime(2026, 1, 1, 0, 1),
        currentTaskId: task.id,
      ),
      structuredResultReference: 'artifact://structured-result',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MissionFinalResultsCard(
            results: [
              MissionFinalResult(
                task: task,
                execution: execution,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byKey(
        const ValueKey<String>('mission-final-results'),
      ),
      findsNothing,
    );

    expect(find.text('Final Results'), findsNothing);
    expect(find.text('Copy All Results'), findsNothing);
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
      find.byKey(
        const ValueKey<String>('mission-final-results'),
      ),
      findsNothing,
    );

    expect(find.text('Final Results'), findsNothing);
    expect(find.text('Copy All Results'), findsNothing);
  });
}

MissionTask _task({
  required String id,
  required String title,
  required int order,
}) {
  return MissionTask(
    id: id,
    missionId: 'mission',
    title: title,
    description: title,
    order: order,
    status: TaskStatus.completed,
    taskType: 'research',
    createdAt: DateTime(2026),
  );
}

MissionTaskExecution _execution({
  required MissionTask task,
  required String id,
  required String outputText,
}) {
  return MissionTaskExecution(
    execution: MissionExecution(
      id: id,
      missionId: 'mission',
      status: ExecutionStatus.completed,
      progress: 1,
      startedAt: DateTime(2026),
      finishedAt: DateTime(2026, 1, 1, 0, 1),
      currentTaskId: task.id,
    ),
    outputText: outputText,
  );
}