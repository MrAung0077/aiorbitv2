import '../../../core/ai/ai_request.dart';
import '../models/mission.dart';
import '../models/mission_task.dart';
import '../models/task_status.dart';

class MissionTaskAIRequestBuilder {
  const MissionTaskAIRequestBuilder();

  static const int _maxPreviousResults = 3;
  static const int _maxPreviousContextChars = 6000;

  AIRequest build({required Mission mission, required MissionTask task}) {
    if (task.missionId != mission.id) {
      throw ArgumentError.value(
        task.missionId,
        'task.missionId',
        'Task does not belong to the mission.',
      );
    }

    final missionGoal = mission.goal.trim();
    final userContext = mission.userContext?.trim();
    final inputContext = task.inputContext?.trim();

    final previousAcceptedResults = _previousAcceptedResults(
      mission: mission,
      currentTask: task,
    );

    final promptLines = <String>[
      'Complete this mission task.',
      '',
      if (missionGoal.isNotEmpty) 'Mission goal: $missionGoal',
      if (userContext != null && userContext.isNotEmpty)
        'User context: $userContext',
      if (previousAcceptedResults.isNotEmpty) ...<String>[
        '',
        'Previous accepted results:',
        ...previousAcceptedResults,
      ],
      'Title: ${task.title.trim()}',
      'Description: ${task.description.trim()}',
      'Task type: ${task.taskType.trim()}',
      if (inputContext != null && inputContext.isNotEmpty)
        'Input context: $inputContext',
    ];

    return AIRequest.fromPrompt(
      prompt: promptLines.join('\n'),
      metadata: <String, Object?>{
        'missionId': mission.id,
        'taskId': task.id,
        'taskType': task.taskType,
        'missionGoal': missionGoal,
        'missionCategory': mission.category.name,
        if (userContext != null && userContext.isNotEmpty)
          'userContext': userContext,
        if (previousAcceptedResults.isNotEmpty)
          'previousAcceptedResultCount': previousAcceptedResults.length,
      },
    );
  }

  List<String> _previousAcceptedResults({
    required Mission mission,
    required MissionTask currentTask,
  }) {
    final eligible = <MissionTask>[];

    for (final task in mission.tasks) {
      if (task.id == currentTask.id) {
        break;
      }

      if (task.status != TaskStatus.completed) {
        continue;
      }

      final output = task.output?.trim();

      if (output == null || output.isEmpty) {
        continue;
      }

      eligible.add(task);
    }

    final latestEligible = eligible.length <= _maxPreviousResults
        ? eligible
        : eligible.sublist(eligible.length - _maxPreviousResults);

    final selected = <String>[];
    var remainingChars = _maxPreviousContextChars;

    for (final task in latestEligible.reversed) {
      final title = task.title.trim().isEmpty
          ? 'Previous task'
          : task.title.trim();

      final output = task.output!.trim();
      final prefix = '$title:\n';

      if (remainingChars <= prefix.length) {
        break;
      }

      final availableForOutput = remainingChars - prefix.length;

      final boundedOutput = output.length <= availableForOutput
          ? output
          : output.substring(output.length - availableForOutput);

      final entry = '$prefix$boundedOutput';

      selected.add(entry);
      remainingChars -= entry.length;

      if (remainingChars <= 0) {
        break;
      }
    }

    return selected.reversed.toList(growable: false);
  }
}
