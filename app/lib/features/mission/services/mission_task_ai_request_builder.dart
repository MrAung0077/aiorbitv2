import '../../../core/ai/ai_request.dart';
import '../../../core/ai/ai_message.dart';
import '../../../core/text/response_language.dart';
import '../models/mission.dart';
import '../models/mission_task.dart';
import '../models/task_status.dart';

class MissionTaskAIRequestBuilder {
  const MissionTaskAIRequestBuilder();

  static const int _maxPreviousResults = 3;
  static const int _maxPreviousContextChars = 6000;
  static const List<String> _conciseOutputPolicy = <String>[
    'Output policy:',
    '- Complete only the current task. Do not pre-complete future mission tasks or include deliverables that clearly belong to later tasks.',
    '- Use mission context only to understand the current task, not to answer the whole mission.',
    '- Treat accepted prior task outputs as completed deliverables. Use them as context, but do not repeat, rewrite, summarize, or regenerate them unless the current task explicitly asks to revise them.',
    '- Produce only the distinct deliverable defined by the current task title and description. If prior work is relevant, refer to it briefly and build on it instead of restating it.',
    '- Do the requested work and give the usable finished result first. Do not begin with background, strategy theory, or lengthy explanation.',
    '- Default to a concise 100–180-word result and strongly prefer staying under 250 words unless the current task itself explicitly requires a long artifact.',
    '- Use short headings or bullets only when they improve clarity. Return ready-to-use deliverables or short actionable plans, not consultant reports.',
    '- Use plain, beginner-friendly language. Avoid unnecessary jargon and keep internal reasoning or frameworks out of the response.',
    '- Avoid essays, repeated context, generic advice, unnecessary examples, and "If you want, I can..." filler.',
    '- Make reasonable assumptions when safe, but do not invent missing facts to make the deliverable appear complete. If genuinely blocked, state assumptions briefly and ask at most 1–3 short questions.',
    '- Provide longer output only when the user explicitly asks for detail, explanation, long-form content or a report, or when the requested artifact itself must be long.',
    '- End the response once the current task is complete.',
  ];

  AIRequest build({required Mission mission, required MissionTask task}) {
    if (task.missionId != mission.id) {
      throw ArgumentError.value(
        task.missionId,
        'task.missionId',
        'Task does not belong to the mission.',
      );
    }

    final missionGoal = mission.goal.trim();
    final responseLanguage = responseLanguageFor(missionGoal);
    final userContext = mission.userContext?.trim();
    final inputContext = task.inputContext?.trim();

    final previousAcceptedResults = _previousAcceptedResults(
      mission: mission,
      currentTask: task,
    );

    final promptLines = <String>[
      'Complete this mission task.',
      '',
      ..._conciseOutputPolicy,
      '',
      if (missionGoal.isNotEmpty) 'Mission goal: $missionGoal',
      if (userContext != null && userContext.isNotEmpty)
        'User context: $userContext',
      if (responseLanguage != ResponseLanguage.burmese)
        responseLanguageInstructionFor(missionGoal),
      'Honesty: Describe only preparation performed in this response. Do not claim code, files, tests, deployment, designs, videos, or external-tool execution were completed unless the mission context proves it.',
      'When an external execution tool is needed, deliver the complete preparation package and clear handoff instructions instead of a dead end.',
      'Treat numbers, audience ranges, posting times, and performance thresholds as starting assumptions or recommended defaults unless the user supplied evidence.',
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

    return AIRequest(
      messages: <AIMessage>[
        if (responseLanguage == ResponseLanguage.burmese)
          const AIMessage(
            role: AIMessageRole.system,
            content: burmeseResponseWritingPolicy,
          ),
        AIMessage(role: AIMessageRole.user, content: promptLines.join('\n')),
      ],
      responseLanguage: responseLanguage,
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
