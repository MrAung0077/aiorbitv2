import 'package:aiorbit/features/mission/mission_final_results_card.dart';
import 'package:aiorbit/features/mission/mission_task_output_screen.dart';
import 'package:aiorbit/features/mission/models/mission_task.dart';
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
      output: '  Finished competitor research  ',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MissionFinalResultsCard(
            results: [MissionFinalResult(task: task)],
          ),
        ),
      ),
    );

    expect(find.text('Completed outputs'), findsOneWidget);
    expect(find.text('1 completed output.'), findsOneWidget);
    expect(find.text('Research competitors'), findsOneWidget);
    expect(find.text('Finished competitor research'), findsOneWidget);
    expect(find.text('Copy all outputs'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('open-final-result-research')),
    );

    await tester.pumpAndSettle();

    expect(find.byType(MissionTaskOutputScreen), findsOneWidget);
    expect(find.text('Task Output'), findsOneWidget);
    expect(find.text('Accepted Result'), findsOneWidget);
    expect(find.text('Execution Output'), findsNothing);
    expect(find.text('Review before accepting'), findsNothing);

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
      output: '  Finished competitor research  ',
    );

    final secondTask = _task(
      id: 'caption',
      title: 'Write launch caption',
      order: 1,
      output: '  Launch Ovexiq today.  ',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MissionFinalResultsCard(
            results: [
              MissionFinalResult(task: firstTask),
              MissionFinalResult(task: secondTask),
            ],
          ),
        ),
      ),
    );

    expect(find.text('2 completed outputs.'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('copy-all-final-results-button')),
    );

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

    expect(find.text('Copied to clipboard'), findsOneWidget);
  });

  testWidgets('copies an individual final result without opening its output', (
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

    final task = _task(
      id: 'research',
      title: 'Research competitors',
      order: 0,
      output: '  Finished competitor research  ',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MissionFinalResultsCard(
            results: [MissionFinalResult(task: task)],
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('copy-final-result-research')),
    );

    await tester.pump();

    expect(clipboardMessages, hasLength(1));
    expect(clipboardMessages.single.arguments, <String, dynamic>{
      'text': 'Finished competitor research',
    });
    expect(find.text('Copied to clipboard'), findsOneWidget);
    expect(find.byType(MissionTaskOutputScreen), findsNothing);
  });

  testWidgets('partial results stay neutral and exclude incomplete outputs', (
    tester,
  ) async {
    final usableTask = _task(
      id: 'usable',
      title: 'Usable result',
      order: 0,
      output: 'Finished usable output',
    );

    final emptyTask = _task(
      id: 'empty',
      title: 'Empty result',
      order: 1,
      output: '  \n\t ',
    );

    final pendingTask = _task(
      id: 'pending',
      title: 'Pending result',
      order: 2,
      status: TaskStatus.pending,
      output: 'This output has not been accepted.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MissionFinalResultsCard(
            results: [
              MissionFinalResult(task: usableTask),
              MissionFinalResult(task: emptyTask),
              MissionFinalResult(task: pendingTask),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Completed outputs'), findsOneWidget);
    expect(find.text('1 completed output.'), findsOneWidget);
    expect(find.text('Result Pack ready'), findsNothing);
    expect(find.text('Usable result'), findsOneWidget);
    expect(find.text('Finished usable output'), findsOneWidget);

    expect(find.text('Empty result'), findsNothing);
    expect(find.text('Pending result'), findsNothing);

    expect(
      find.byKey(const ValueKey<String>('open-final-result-empty')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('open-final-result-pending')),
      findsNothing,
    );
  });

  testWidgets('only unusable persisted outputs render nothing', (tester) async {
    final task = _task(
      id: 'empty',
      title: 'Empty result',
      order: 0,
      output: '   ',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MissionFinalResultsCard(
            results: [MissionFinalResult(task: task)],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('mission-final-results')),
      findsNothing,
    );

    expect(find.text('Completed outputs'), findsNothing);
    expect(find.text('Copy all outputs'), findsNothing);
  });

  testWidgets('long title and output stay compact in the final results card', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));

    addTearDown(() => tester.binding.setSurfaceSize(null));

    const longTitle =
        'Create a complete market research summary for the Ovexiq '
        'launch strategy across multiple international customer segments';

    const longOutput =
        'This is a deliberately long finished result designed to verify that '
        'the mission final results card remains compact when AI output becomes '
        'much longer than a normal preview. The complete content must still '
        'remain available when the user opens the final result screen, while '
        'the mission detail experience should only show a short preview.';

    final task = _task(
      id: 'long-result',
      title: longTitle,
      order: 0,
      output: longOutput,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MissionFinalResultsCard(
              results: [MissionFinalResult(task: task)],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    final titleWidget = tester.widget<Text>(find.text(longTitle));

    expect(titleWidget.maxLines, 1);
    expect(titleWidget.overflow, TextOverflow.ellipsis);

    final outputWidget = tester.widget<Text>(find.text(longOutput));

    expect(outputWidget.maxLines, 2);
    expect(outputWidget.overflow, TextOverflow.ellipsis);

    await tester.tap(
      find.byKey(const ValueKey<String>('open-final-result-long-result')),
    );

    await tester.pumpAndSettle();

    expect(find.byType(MissionTaskOutputScreen), findsOneWidget);

    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      longOutput,
    );
  });

  testWidgets('multiple final results fit without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));

    addTearDown(() => tester.binding.setSurfaceSize(null));

    final results = List<MissionFinalResult>.generate(5, (index) {
      final task = _task(
        id: 'task-$index',
        title: 'Finished result ${index + 1}',
        order: index,
        output: 'Completed output for finished result ${index + 1}.',
      );

      return MissionFinalResult(task: task);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MissionFinalResultsCard(results: results),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('5 completed outputs.'), findsOneWidget);

    for (var index = 0; index < 5; index++) {
      expect(find.text('Finished result ${index + 1}'), findsOneWidget);

      expect(
        find.byKey(ValueKey<String>('open-final-result-task-$index')),
        findsOneWidget,
      );
    }

    expect(find.text('Copy all outputs'), findsOneWidget);
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

    expect(find.text('Completed outputs'), findsNothing);
    expect(find.text('Copy all outputs'), findsNothing);
  });
}

MissionTask _task({
  required String id,
  required String title,
  required int order,
  String? output,
  TaskStatus status = TaskStatus.completed,
}) {
  return MissionTask(
    id: id,
    missionId: 'mission',
    title: title,
    description: title,
    order: order,
    status: status,
    taskType: 'research',
    output: output,
    createdAt: DateTime(2026),
  );
}
