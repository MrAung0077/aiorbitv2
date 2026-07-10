import '../models/ai_plan.dart';
import '../models/coach_profile.dart';

class BrainService {
  const BrainService();

  AIPlan createPlan(CoachProfile profile) {
    return AIPlan(
      bestAI: "ChatGPT",
      reason: "Best for beginner guidance and step-by-step planning.",
      firstTask: "Write your goal clearly in one simple paragraph.",
      nextAction: "Follow the 7-day roadmap and complete Day 1.",
      roadmap: const [
        "Day 1: Understand your goal clearly.",
        "Day 2: Learn the basic tools.",
        "Day 3: Try one small task.",
        "Day 4: Improve your result.",
        "Day 5: Practice with AI.",
        "Day 6: Ask better questions.",
        "Day 7: Review your progress.",
      ],
      optimizedPrompt:
          '''
Act as a friendly AI coach.

My profile:
Goal: ${profile.goal}
Why: ${profile.why}
Situation: ${profile.situation}
Resource: ${profile.resource}
Experience: ${profile.experience}

Create a simple 7-day roadmap for me.
Explain step by step.
Give me today's first task.
''',
    );
  }
}
