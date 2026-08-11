import 'package:aiorbit/features/mission/mission_preview_screen.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:aiorbit/features/mission/models/mission_suggestion.dart';
import 'package:aiorbit/features/mission/providers/mission_provider.dart';
import 'package:aiorbit/features/mission/services/memory_mission_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('created mission uses persistence-neutral success copy', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: <Override>[
        missionRepositoryProvider.overrideWithValue(MemoryMissionRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MissionPreviewScreen(
            suggestion: MissionSuggestion(
              title: 'Prepare a beta launch',
              goal: 'Create a practical beta launch plan',
              category: MissionCategory.marketing,
              reason: 'The goal benefits from an ordered workflow.',
              plannedSteps: <String>['Draft the launch plan'],
            ),
          ),
        ),
      ),
    );

    final startMission = find.text('Start Mission');
    await tester.ensureVisible(startMission);
    await tester.tap(startMission);
    await tester.pump();

    expect(
      find.text('Your mission has been created and saved.'),
      findsOneWidget,
    );
    expect(find.textContaining('saved for this session'), findsNothing);
  });
}
