import 'package:flutter/material.dart';

import '../../core/models/ai_plan.dart';

class ResultScreen extends StatelessWidget {
  final AIPlan plan;

  const ResultScreen({super.key, required this.plan});

  void goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Your AI Plan"),
        actions: [
          IconButton(
            tooltip: "Home",
            icon: const Icon(Icons.home_outlined),
            onPressed: () => goHome(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            const Text(
              "🎯 Your Plan is Ready",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            _card("🏆 Best AI", plan.bestAI),
            _card("💡 Why", plan.reason),
            _card("✅ First Task", plan.firstTask),
            _card("➡️ Next Action", plan.nextAction),
            _card("✨ Optimized Prompt", plan.optimizedPrompt),

            const SizedBox(height: 10),

            const Text(
              "🗓️ 7-Day Roadmap",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            ...plan.roadmap.map((day) => _card("", day)),
          ],
        ),
      ),
    );
  }

  Widget _card(String title, String body) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          title.isEmpty ? body : "$title\n\n$body",
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }
}
