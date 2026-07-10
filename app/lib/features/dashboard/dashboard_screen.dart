import 'package:flutter/material.dart';

import '../../core/models/ai_plan.dart';
import '../../core/widgets/mission_card.dart';

class DashboardScreen extends StatelessWidget {
  final AIPlan plan;

  const DashboardScreen({super.key, required this.plan});

  void goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AIOrbit"),
        actions: [
          IconButton(
            tooltip: "Home",
            icon: const Icon(Icons.home_outlined),
            onPressed: () => goHome(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            "👋 Your AI Coach",
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          const Text(
            "Day 1 of your 7-day journey",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),

          const SizedBox(height: 18),

          LinearProgressIndicator(
            value: 1 / 7,
            minHeight: 10,
            borderRadius: BorderRadius.circular(12),
          ),

          const SizedBox(height: 28),

          MissionCard(
            title: plan.firstTask,
            subtitle: plan.nextAction,
            time: "25 min",
            onStart: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("AI Chat coming next 🚀")),
              );
            },
          ),

          const SizedBox(height: 22),

          _sectionCard(
            title: "🤖 Recommended AI",
            body: "${plan.bestAI}\n\n${plan.reason}",
          ),

          _sectionCard(
            title: "💬 AI Coach Message",
            body:
                "You don't need to finish everything today. Just complete today's mission. One step every day.",
          ),

          const SizedBox(height: 8),

          const Text(
            "📈 Your Journey",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          ...plan.roadmap.map((day) => _journeyItem(day)),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required String body}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          "$title\n\n$body",
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }

  Widget _journeyItem(String text) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.radio_button_unchecked),
        title: Text(text),
      ),
    );
  }
}
