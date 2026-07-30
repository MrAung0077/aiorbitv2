import 'mission_category.dart';

class MissionSuggestion {
  const MissionSuggestion({
    required this.title,
    required this.goal,
    required this.category,
    required this.reason,
    required this.plannedSteps,
  });

  final String title;
  final String goal;
  final MissionCategory category;
  final String reason;
  final List<String> plannedSteps;
}
