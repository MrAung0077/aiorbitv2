import '../coach/coach_screen.dart';

import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("🚀", style: TextStyle(fontSize: 70)),

                const SizedBox(height: 24),

                Text(
                  AppStrings.appName,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  AppStrings.slogan,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20),
                ),

                const SizedBox(height: 60),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CoachScreen()),
                      );
                    },
                    child: Text(AppStrings.startButton),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
