import 'mission_status.dart';
import 'mission_task.dart';
import 'mission_category.dart';

class Mission {
  const Mission({
    required this.id,
    required this.title,
    required this.goal,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.currentTaskIndex,
    required this.progressPercent,
    required this.tasks,
    this.conversationId,
    this.userContext,
  });

  final String id;
  final String title;
  final String goal;
  final MissionCategory category;
  final MissionStatus status;

  final DateTime createdAt;
  final DateTime updatedAt;

  final int currentTaskIndex;
  final double progressPercent;

  final List<MissionTask> tasks;

  final String? conversationId;
  final String? userContext;

  Mission copyWith({
    String? id,
    String? title,
    String? goal,
    MissionCategory? category,
    MissionStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? currentTaskIndex,
    double? progressPercent,
    List<MissionTask>? tasks,
    String? conversationId,
    String? userContext,
  }) {
    return Mission(
      id: id ?? this.id,
      title: title ?? this.title,
      goal: goal ?? this.goal,
      category: category ?? this.category,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      currentTaskIndex: currentTaskIndex ?? this.currentTaskIndex,
      progressPercent: progressPercent ?? this.progressPercent,
      tasks: tasks ?? this.tasks,
      conversationId: conversationId ?? this.conversationId,
      userContext: userContext ?? this.userContext,
    );
  }
}
