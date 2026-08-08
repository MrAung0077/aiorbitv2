import 'package:aiorbit/features/mission/models/mission.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:aiorbit/features/mission/models/mission_status.dart';
import 'package:aiorbit/features/mission/models/mission_task.dart';
import 'package:aiorbit/features/mission/models/task_status.dart';
import 'package:aiorbit/features/mission/services/mission_task_ai_request_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('build includes mission goal and task context', () {
    final mission = Mission(
      id: 'mission-1',
      title: 'Launch Ovexiq',
      goal: 'Create a strong launch campaign for Ovexiq creators',
      category: MissionCategory.productivity,
      status: MissionStatus.active,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      currentTaskIndex: 0,
      progressPercent: 0,
      tasks: <MissionTask>[
        MissionTask(
          id: 'task-1',
          missionId: 'mission-1',
          title: 'Research competitors',
          description: 'Find the strongest competing creator tools',
          order: 0,
          status: TaskStatus.pending,
          taskType: 'research',
          inputContext: 'Focus on Facebook, TikTok, and YouTube creators.',
          createdAt: DateTime(2026),
        ),
      ],
    );

    final task = mission.tasks.single;

    const builder = MissionTaskAIRequestBuilder();

    final request = builder.build(
      mission: mission,
      task: task,
    );

    final prompt = request.latestUserPrompt;

    expect(
      prompt,
      contains(
        'Mission goal: Create a strong launch campaign for Ovexiq creators',
      ),
    );

    expect(
      prompt,
      contains('Title: Research competitors'),
    );

    expect(
      prompt,
      contains(
        'Description: Find the strongest competing creator tools',
      ),
    );

    expect(
      prompt,
      contains('Task type: research'),
    );

    expect(
      prompt,
      contains(
        'Input context: Focus on Facebook, TikTok, and YouTube creators.',
      ),
    );
  });

  test('build includes mission context in request metadata', () {
    final mission = Mission(
      id: 'mission-1',
      title: 'Launch Ovexiq',
      goal: 'Create a launch campaign',
      category: MissionCategory.productivity,
      status: MissionStatus.active,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      currentTaskIndex: 0,
      progressPercent: 0,
      tasks: <MissionTask>[
        MissionTask(
          id: 'task-1',
          missionId: 'mission-1',
          title: 'Research',
          description: 'Research the market',
          order: 0,
          status: TaskStatus.pending,
          taskType: 'research',
          createdAt: DateTime(2026),
        ),
      ],
    );

    const builder = MissionTaskAIRequestBuilder();

    final request = builder.build(
      mission: mission,
      task: mission.tasks.single,
    );

    expect(request.metadata['missionId'], 'mission-1');
    expect(request.metadata['taskId'], 'task-1');
    expect(request.metadata['taskType'], 'research');

    expect(
      request.metadata['missionGoal'],
      'Create a launch campaign',
    );

    expect(
      request.metadata['missionCategory'],
      MissionCategory.productivity.name,
    );
  });

  test('build rejects a task that belongs to another mission', () {
    final mission = Mission(
      id: 'mission-1',
      title: 'Mission',
      goal: 'Complete the mission',
      category: MissionCategory.productivity,
      status: MissionStatus.active,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      currentTaskIndex: 0,
      progressPercent: 0,
      tasks: const <MissionTask>[],
    );

    final foreignTask = MissionTask(
      id: 'task-foreign',
      missionId: 'mission-2',
      title: 'Foreign task',
      description: 'Does not belong to this mission',
      order: 0,
      status: TaskStatus.pending,
      taskType: 'research',
      createdAt: DateTime(2026),
    );

    const builder = MissionTaskAIRequestBuilder();

    expect(
      () => builder.build(
        mission: mission,
        task: foreignTask,
      ),
      throwsArgumentError,
    );
  });
}