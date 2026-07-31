import 'package:aiorbit/features/chat/models/brain_status.dart';
import 'package:aiorbit/features/chat/models/router_decision.dart';
import 'package:aiorbit/features/chat/widgets/brain_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses outcome-focused copy without provider details', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BrainOverlay(
          currentStatus: BrainStatus.selectingAi,
          decision: RouterDecision(
            task: 'Research',
            reasoning: 'Internal routing explanation',
            recommendedAi: 'Gemini',
            complexity: 'Medium',
            confidence: 94,
          ),
        ),
      ),
    );

    expect(find.text('Ovexiq'), findsOneWidget);
    expect(find.text('Understanding your goal'), findsOneWidget);
    expect(find.text('Planning the best approach'), findsOneWidget);
    expect(find.text('Preparing your result'), findsOneWidget);

    expect(find.text('AIOrbit Brain'), findsNothing);
    expect(find.text('Recommended AI'), findsNothing);
    expect(find.text('Gemini'), findsNothing);
    expect(find.text('Internal routing explanation'), findsNothing);
  });
}
