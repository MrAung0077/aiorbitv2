import 'package:aiorbit/features/chat/widgets/finished_result_card.dart';
import 'package:aiorbit/features/mission/services/chat_mission_result_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows one result directly without an internal label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinishedResultCard(
            result: const ChatMissionResult(
              deliverables: <ChatMissionDeliverable>[
                ChatMissionDeliverable(title: 'Internal name', content: 'Done'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Done'), findsNWidgets(2));
    expect(find.text('Internal name'), findsNothing);
    expect(find.text('Mission'), findsNothing);
    expect(find.text('Task'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('copy-finished-result-button')),
      findsOneWidget,
    );
  });

  testWidgets('labels multiple finished deliverables clearly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinishedResultCard(
            result: const ChatMissionResult(
              deliverables: <ChatMissionDeliverable>[
                ChatMissionDeliverable(title: 'Brief', content: 'Final brief'),
                ChatMissionDeliverable(title: 'Plan', content: 'Final plan'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Brief'), findsOneWidget);
    expect(find.text('Final brief'), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Final plan'), findsOneWidget);
  });
}
