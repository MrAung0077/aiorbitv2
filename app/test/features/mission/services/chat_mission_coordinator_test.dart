import 'dart:async';

import 'package:aiorbit/features/mission/controllers/mission_controller.dart';
import 'package:aiorbit/features/mission/models/mission.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:aiorbit/features/mission/models/mission_status.dart';
import 'package:aiorbit/features/mission/models/mission_suggestion.dart';
import 'package:aiorbit/features/mission/models/mission_task.dart';
import 'package:aiorbit/features/mission/models/task_status.dart';
import 'package:aiorbit/features/mission/services/chat_mission_coordinator.dart';
import 'package:aiorbit/features/mission/services/memory_mission_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concurrent starts create and run exactly one Mission', () async {
    final repository = MemoryMissionRepository();
    final controller = MissionController(repository: repository);
    final runCompleter = Completer<Mission>();
    var runCount = 0;
    final coordinator = ChatMissionCoordinator(
      missionController: controller,
      restoreExecutions: (_) async {},
      runMission: (missionId) {
        runCount++;
        return runCompleter.future;
      },
    );

    final first = coordinator.startOrResume(
      suggestion: _suggestion(),
      conversationId: 'conversation-1',
    );
    final second = coordinator.startOrResume(
      suggestion: _suggestion(),
      conversationId: 'conversation-1',
    );
    await Future<void>.delayed(Duration.zero);

    final missions = await repository.getAllMissions();
    expect(missions, hasLength(1));
    expect(runCount, 1);

    runCompleter.complete(_completed(missions.single));

    final results = await Future.wait(<Future<ChatMissionRunResult>>[
      first,
      second,
    ]);
    expect(results.map((result) => result.outcome),
        everyElement(ChatMissionRunOutcome.completed));
  });

  test('reuses a Mission linked to the conversation', () async {
    final repository = MemoryMissionRepository();
    final controller = MissionController(repository: repository);
    final existingMission = _mission(
      id: 'existing-mission',
      conversationId: 'conversation-2',
    );
    await repository.saveMission(existingMission);
    final coordinator = ChatMissionCoordinator(
      missionController: controller,
      restoreExecutions: (_) async {},
      runMission: (missionId) async {
        expect(missionId, existingMission.id);
        return _completed(existingMission);
      },
    );

    final result = await coordinator.startOrResume(
      suggestion: _suggestion(),
      conversationId: existingMission.conversationId,
    );

    expect(result.wasCreated, isFalse);
    expect(result.mission?.id, existingMission.id);
    expect(await repository.getAllMissions(), hasLength(1));
  });

  test('explicitly resumes a cancelled linked Mission without losing outputs', () async {
    final repository = MemoryMissionRepository();
    final controller = MissionController(repository: repository);
    final baseMission = _mission(
      id: 'cancelled-mission',
      conversationId: 'conversation-cancelled',
    );
    final existingMission = baseMission.copyWith(
      status: MissionStatus.cancelled,
      tasks: <MissionTask>[
        baseMission.tasks.single.copyWith(
          status: TaskStatus.completed,
          output: 'Accepted prior output',
          completedAt: DateTime(2026, 1, 2),
        ),
        MissionTask(
          id: 'cancelled-mission-task-2',
          missionId: 'cancelled-mission',
          title: 'Deliver',
          description: 'Deliver the plan.',
          taskType: 'deliver',
          order: 1,
          status: TaskStatus.pending,
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );
    await repository.saveMission(existingMission);
    Mission? missionGivenToRun;
    final coordinator = ChatMissionCoordinator(
      missionController: controller,
      restoreExecutions: (_) async {},
      runMission: (missionId) async {
        missionGivenToRun = await repository.getMission(missionId);
        return _completed(missionGivenToRun!);
      },
    );

    final result = await coordinator.startOrResume(
      suggestion: _suggestion(),
      conversationId: existingMission.conversationId,
    );

    expect(result.wasCreated, isFalse);
    expect(missionGivenToRun?.id, existingMission.id);
    expect(missionGivenToRun?.status, MissionStatus.active);
    expect(missionGivenToRun?.tasks.first.status, TaskStatus.completed);
    expect(missionGivenToRun?.tasks.first.output, 'Accepted prior output');
    expect(result.outcome, ChatMissionRunOutcome.completed);
    expect(await repository.getAllMissions(), hasLength(1));
  });

  test('restores persisted execution state before rerunning', () async {
    final repository = MemoryMissionRepository();
    final controller = MissionController(repository: repository);
    final existingMission = _mission(
      id: 'recovered-mission',
      conversationId: 'conversation-3',
    );
    await repository.saveMission(existingMission);
    var restored = false;
    final coordinator = ChatMissionCoordinator(
      missionController: controller,
      restoreExecutions: (missionId) async {
        expect(missionId, existingMission.id);
        restored = true;
      },
      runMission: (missionId) async {
        expect(restored, isTrue);
        return _completed(existingMission);
      },
    );

    final result = await coordinator.startOrResume(
      suggestion: _suggestion(),
      conversationId: existingMission.conversationId,
    );

    expect(result.outcome, ChatMissionRunOutcome.completed);
  });

  test('maps an incomplete automatic run to a safe failure outcome', () async {
    final repository = MemoryMissionRepository();
    final controller = MissionController(repository: repository);
    final existingMission = _mission(
      id: 'failed-mission',
      conversationId: 'conversation-4',
    );
    await repository.saveMission(existingMission);
    final coordinator = ChatMissionCoordinator(
      missionController: controller,
      restoreExecutions: (_) async {},
      runMission: (_) async => existingMission,
    );

    final result = await coordinator.startOrResume(
      suggestion: _suggestion(),
      conversationId: existingMission.conversationId,
    );

    expect(result.outcome, ChatMissionRunOutcome.failed);
  });
}

MissionSuggestion _suggestion() {
  return const MissionSuggestion(
    title: 'Build a launch plan',
    goal: 'Build a launch plan',
    category: MissionCategory.business,
    reason: 'Requires connected work.',
    plannedSteps: <String>['Research', 'Deliver'],
  );
}

Mission _mission({required String id, required String conversationId}) {
  final createdAt = DateTime(2026, 1, 1);

  return Mission(
    id: id,
    title: 'Launch plan',
    goal: 'Build a launch plan',
    category: MissionCategory.business,
    status: MissionStatus.active,
    createdAt: createdAt,
    updatedAt: createdAt,
    currentTaskIndex: 0,
    progressPercent: 0,
    conversationId: conversationId,
    tasks: <MissionTask>[
      MissionTask(
        id: '$id-task',
        missionId: id,
        title: 'Research',
        description: 'Research the launch.',
        taskType: 'research',
        order: 0,
        status: TaskStatus.pending,
        createdAt: createdAt,
      ),
    ],
  );
}

Mission _completed(Mission mission) {
  return mission.copyWith(
    tasks: mission.tasks
        .map(
          (task) => task.copyWith(
            status: TaskStatus.completed,
            output: 'Finished result',
            completedAt: DateTime(2026, 1, 2),
          ),
        )
        .toList(growable: false),
  );
}
