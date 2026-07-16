class RouterDecision {
  const RouterDecision({
    required this.task,
    required this.reasoning,
    required this.recommendedAi,
    required this.complexity,
    required this.confidence,
  });

  final String task;
  final String reasoning;
  final String recommendedAi;
  final String complexity;

  /// 0 - 100
  final int confidence;
}
