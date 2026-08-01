import 'task_status.dart';

class MissionTask {
  const MissionTask({
    required this.id,
    required this.missionId,
    required this.title,
    required this.description,
    required this.order,
    required this.status,
    required this.taskType,
    this.recommendedProvider,
    this.inputContext,
    this.output,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final String missionId;

  final String title;
  final String description;

  final int order;

  final TaskStatus status;

  final String taskType;

  final String? recommendedProvider;

  final String? inputContext;

  final String? output;

  final DateTime createdAt;

  final DateTime? completedAt;

  MissionTask copyWith({
    TaskStatus? status,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return MissionTask(
      id: id,
      missionId: missionId,
      title: title,
      description: description,
      order: order,
      status: status ?? this.status,
      taskType: taskType,
      recommendedProvider: recommendedProvider,
      inputContext: inputContext,
      output: output,
      createdAt: createdAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    );
  }
}
