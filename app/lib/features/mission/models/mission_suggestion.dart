import 'mission_category.dart';

class MissionSuggestion {
  const MissionSuggestion({
    required this.title,
    required this.goal,
    required this.category,
    required this.reason,
  });

  final String title;
  final String goal;
  final MissionCategory category;
  final String reason;
}
