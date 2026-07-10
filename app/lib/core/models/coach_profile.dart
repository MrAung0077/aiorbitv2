class CoachProfile {
  final String goal;
  final String why;
  final String situation;
  final String resource;
  final String experience;

  const CoachProfile({
    required this.goal,
    required this.why,
    required this.situation,
    required this.resource,
    required this.experience,
  });

  Map<String, String> toMap() {
    return {
      "goal": goal,
      "why": why,
      "situation": situation,
      "resource": resource,
      "experience": experience,
    };
  }

  @override
  String toString() {
    return '''
Goal: $goal
Why: $why
Situation: $situation
Resource: $resource
Experience: $experience
''';
  }
}
