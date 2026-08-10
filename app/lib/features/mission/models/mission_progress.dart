import 'mission_task.dart';
import 'task_status.dart';

class MissionProgress {
  const MissionProgress._(
    this.completedTasks,
    this.totalTasks,
    this._acceptedCompletedTasks,
  );

  factory MissionProgress.fromTasks(Iterable<MissionTask> tasks) {
    final taskList = tasks.toList(growable: false);

    return MissionProgress._(
      taskList.where((task) => task.status == TaskStatus.completed).length,
      taskList.length,
      taskList
          .where(
            (task) =>
                task.status == TaskStatus.completed &&
                task.output?.trim().isNotEmpty == true,
          )
          .length,
    );
  }

  final int completedTasks;
  final int totalTasks;
  final int _acceptedCompletedTasks;

  double get percent {
    if (totalTasks <= 0) {
      return 0;
    }

    return (completedTasks / totalTasks).clamp(0.0, 1.0).toDouble();
  }

  int get percentage => (percent * 100).round();

  bool get isComplete {
    return totalTasks > 0 && _acceptedCompletedTasks >= totalTasks;
  }
}
