import 'package:aiorbit/features/chat/widgets/finished_result_card.dart';
import 'package:aiorbit/features/mission/services/chat_mission_result_adapter.dart';
import 'package:aiorbit/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a single named output in a completed Result Pack', (
    tester,
  ) async {
    await tester.pumpWidget(
      _resultCardApp(
        result: const ChatMissionResult(
          deliverables: <ChatMissionDeliverable>[
            ChatMissionDeliverable(title: 'Plan', content: 'Done'),
          ],
        ),
      ),
    );

    expect(find.text('Result Pack ready'), findsOneWidget);
    expect(find.text('1 output ready.'), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('copy-finished-result-button')),
      findsOneWidget,
    );
  });

  testWidgets('labels multiple finished deliverables clearly', (tester) async {
    await tester.pumpWidget(
      _resultCardApp(
        result: const ChatMissionResult(
          deliverables: <ChatMissionDeliverable>[
            ChatMissionDeliverable(title: 'Brief', content: 'Final brief'),
            ChatMissionDeliverable(title: 'Plan', content: 'Final plan'),
          ],
        ),
      ),
    );

    expect(find.text('Result Pack ready'), findsOneWidget);
    expect(find.text('2 outputs ready.'), findsOneWidget);
    expect(find.text('Brief'), findsOneWidget);
    expect(find.text('Final brief'), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Final plan'), findsOneWidget);
  });

  testWidgets('uses the selected locale for Result Pack presentation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _resultCardApp(
        locale: const Locale('my'),
        result: const ChatMissionResult(
          deliverables: <ChatMissionDeliverable>[
            ChatMissionDeliverable(title: 'အစီအစဉ်', content: 'ပြီးပါပြီ'),
          ],
        ),
      ),
    );

    expect(find.text('ရလဒ်အစုံ အဆင်သင့်ဖြစ်ပါပြီ'), findsOneWidget);
    expect(find.text('ရလဒ် ၁ ခု အဆင်သင့်ဖြစ်ပါပြီ။'), findsOneWidget);
  });
}

Widget _resultCardApp({
  required ChatMissionResult result,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: FinishedResultCard(result: result)),
  );
}
