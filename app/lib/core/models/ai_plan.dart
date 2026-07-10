class AIPlan {
  final String bestAI;
  final String reason;
  final String firstTask;
  final String nextAction;
  final List<String> roadmap;
  final String optimizedPrompt;

  const AIPlan({
    required this.bestAI,
    required this.reason,
    required this.firstTask,
    required this.nextAction,
    required this.roadmap,
    required this.optimizedPrompt,
  });
}
