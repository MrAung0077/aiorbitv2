import 'package:flutter/material.dart';

import '../../core/models/coach_profile.dart';
import '../../core/services/brain_service.dart';
import '../dashboard/dashboard_screen.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  int currentStep = 0;

  String? selectedGoal;
  String? selectedWhy;
  String? selectedSituation;
  String? selectedResource;
  String? selectedExperience;

  final goals = [
    "💰 Make Money",
    "📚 Learn AI",
    "💻 Build App",
    "🚀 Grow Business",
    "🎬 Create Content",
  ];

  final whyOptions = [
    "💵 I want financial freedom",
    "👨‍👩‍👧 I want to support my family",
    "🔄 I want to change my life",
    "📈 I want to grow my future",
  ];

  final situations = [
    "🎓 Student",
    "💼 Employee",
    "🏪 Business Owner",
    "🎬 Content Creator",
    "🤔 Just Exploring",
  ];

  final resources = [
    "📱 Phone only",
    "💻 Laptop / PC",
    "📱💻 Phone + Laptop",
    "⏰ I have time",
    "💸 I have some budget",
  ];

  final experiences = ["🌱 Beginner", "🙂 Intermediate", "🔥 Advanced"];

  List<String> get options {
    if (currentStep == 0) return goals;
    if (currentStep == 1) return whyOptions;
    if (currentStep == 2) return situations;
    if (currentStep == 3) return resources;
    return experiences;
  }

  String get title {
    if (currentStep == 0) return "🎯 What do you want to achieve?";
    if (currentStep == 1) return "❤️ Why is this important to you?";
    if (currentStep == 2) return "👤 Tell us about yourself";
    if (currentStep == 3) return "💻 What resources do you have?";
    return "📈 What's your experience level?";
  }

  String? get selected {
    if (currentStep == 0) return selectedGoal;
    if (currentStep == 1) return selectedWhy;
    if (currentStep == 2) return selectedSituation;
    if (currentStep == 3) return selectedResource;
    return selectedExperience;
  }

  void choose(String value) {
    setState(() {
      if (currentStep == 0) selectedGoal = value;
      if (currentStep == 1) selectedWhy = value;
      if (currentStep == 2) selectedSituation = value;
      if (currentStep == 3) selectedResource = value;
      if (currentStep == 4) selectedExperience = value;
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      next();
    });
  }

  void next() {
    if (currentStep < 4) {
      setState(() => currentStep++);
      return;
    }

    final goal = selectedGoal;
    final why = selectedWhy;
    final situation = selectedSituation;
    final resource = selectedResource;
    final experience = selectedExperience;

    if (goal == null ||
        why == null ||
        situation == null ||
        resource == null ||
        experience == null) {
      debugPrint(
        'Coach profile incomplete: '
        'goal=$goal, '
        'why=$why, '
        'situation=$situation, '
        'resource=$resource, '
        'experience=$experience',
      );
      return;
    }

    final profile = CoachProfile(
      goal: goal,
      why: why,
      situation: situation,
      resource: resource,
      experience: experience,
    );

    final plan = const BrainService().createPlan(profile);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DashboardScreen(plan: plan)),
    );
  }

  void back() {
    if (currentStep == 0) {
      Navigator.pop(context);
    } else {
      setState(() => currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Coach"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: back,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Step ${currentStep + 1} / 5"),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (currentStep + 1) / 5,
              minHeight: 10,
              borderRadius: BorderRadius.circular(12),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final item = options[index];
                  final isSelected = selected == item;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => choose(item),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xffEEF2FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xff4F46E5)
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xff4F46E5),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
