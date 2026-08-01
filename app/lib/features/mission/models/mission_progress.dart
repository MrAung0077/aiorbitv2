import 'mission_task.dart';
import 'task_status.dart';

class MissionProgress {
  const MissionProgress({
    required this.completedTasks,
    required this.totalTasks,
  });

  factory MissionProgress.fromTasks(Iterable<MissionTask> tasks) {
    final taskList = tasks.toList(growable: false);

    return MissionProgress(
      completedTasks: taskList
          .where((task) => task.status == TaskStatus.completed)
          .length,
      totalTasks: taskList.length,
    );
  }

  final int completedTasks;
  final int totalTasks;

  double get percent {
    if (totalTasks <= 0) {
      return 0;
    }

    return (completedTasks / totalTasks).clamp(0.0, 1.0).toDouble();
  }

  int get percentage => (percent * 100).round();

  bool get isComplete {
    return totalTasks > 0 && completedTasks >= totalTasks;
  }
}
