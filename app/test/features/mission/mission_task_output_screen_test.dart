import 'package:aiorbit/features/mission/mission_task_output_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('review mode shows temporary output guidance', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MissionTaskOutputScreen(
          taskTitle: '  Write launch caption  ',
          outputText: '  Launch Ovexiq today with confidence.  ',
          mode: MissionTaskOutputMode.review,
        ),
      ),
    );

    expect(find.text('Task Output'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);
    expect(find.text('Write launch caption'), findsOneWidget);
    expect(find.text('Output'), findsOneWidget);
    expect(find.text('Execution Output'), findsOneWidget);
    expect(find.text('Review before accepting'), findsOneWidget);
    expect(find.text('Accepted Result'), findsNothing);
    expect(find.text('Completed Output'), findsNothing);
    expect(find.textContaining('Final Result'), findsNothing);
    expect(find.text('5 words'), findsOneWidget);
    expect(find.text('36 characters'), findsOneWidget);
    expect(find.text('Copy Output'), findsOneWidget);
    expect(find.text('Copy with Task Title'), findsOneWidget);
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      'Launch Ovexiq today with confidence.',
    );
  });

  testWidgets('copy output button copies trimmed output', (tester) async {
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

    await tester.pumpWidget(
      const MaterialApp(
        home: MissionTaskOutputScreen(
          taskTitle: 'Research competitors',
          outputText: '  Finished competitor research  ',
          mode: MissionTaskOutputMode.review,
        ),
      ),
    );

    final copyButton = find.byKey(const ValueKey<String>('copy-output-button'));

    await tester.tap(copyButton);
    await tester.pump();

    expect(clipboardMessages, hasLength(1));
    expect(clipboardMessages.single.arguments, <String, dynamic>{
      'text': 'Finished competitor research',
    });
    expect(find.text('Output copied'), findsOneWidget);
  });

  testWidgets('accepted mode shows and copies the accepted result', (
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

    await tester.pumpWidget(
      const MaterialApp(
        home: MissionTaskOutputScreen(
          taskTitle: '  Research competitors  ',
          outputText: '  Finished competitor research  ',
          mode: MissionTaskOutputMode.accepted,
        ),
      ),
    );

    expect(find.text('Accepted Result'), findsOneWidget);
    expect(find.text('Execution Output'), findsNothing);
    expect(find.text('Review before accepting'), findsNothing);
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      'Finished competitor research',
    );

    final copyButton = find.byKey(
      const ValueKey<String>('copy-task-and-output-button'),
    );

    await tester.tap(copyButton);
    await tester.pump();

    expect(clipboardMessages, hasLength(1));
    expect(clipboardMessages.single.arguments, <String, dynamic>{
      'text': 'Research competitors\n\nFinished competitor research',
    });
    expect(find.text('Task and output copied'), findsOneWidget);
  });
}
