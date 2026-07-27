class MissionProgress {
  const MissionProgress({
    required this.completedTasks,
    required this.totalTasks,
  });

  final int completedTasks;
  final int totalTasks;

  double get percent {
    if (totalTasks <= 0) {
      return 0;
    }

    return completedTasks / totalTasks;
  }

  bool get isComplete {
    return totalTasks > 0 && completedTasks >= totalTasks;
  }
}
