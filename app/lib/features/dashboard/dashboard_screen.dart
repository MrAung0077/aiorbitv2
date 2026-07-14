import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/ai_plan.dart';
import '../../core/widgets/mission_card.dart';
import '../chat/ai_chat_screen.dart';
import '../chat/providers/chat_controller.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key, required this.plan});

  final AIPlan plan;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _promptFocusNode = FocusNode();

  @override
  void dispose() {
    _promptController.dispose();
    _promptFocusNode.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _askAIOrbit() async {
    final prompt = _promptController.text.trim();
    final chatState = ref.read(chatControllerProvider);

    if (prompt.isEmpty || chatState.isSending) {
      return;
    }

    _promptController.clear();
    _promptFocusNode.unfocus();

    await ref.read(chatControllerProvider.notifier).sendMessage(prompt);

    if (!mounted) {
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AIChatScreen()));
  }

  void _openChat() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AIChatScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatState = ref.watch(chatControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AIOrbit'),
        actions: [
          IconButton(
            tooltip: 'Open chat',
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: _openChat,
          ),
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home_outlined),
            onPressed: _goHome,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'What can AIOrbit help you with?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask once. AIOrbit will handle the rest.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),

          _PromptComposer(
            controller: _promptController,
            focusNode: _promptFocusNode,
            isSending: chatState.isSending,
            onSend: _askAIOrbit,
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickPromptChip(
                label: 'Write',
                icon: Icons.edit_outlined,
                onTap: () => _setQuickPrompt('Help me write '),
              ),
              _QuickPromptChip(
                label: 'Research',
                icon: Icons.search_rounded,
                onTap: () => _setQuickPrompt('Research this topic for me: '),
              ),
              _QuickPromptChip(
                label: 'Code',
                icon: Icons.code_rounded,
                onTap: () =>
                    _setQuickPrompt('Help me build or fix this code: '),
              ),
              _QuickPromptChip(
                label: 'Plan',
                icon: Icons.route_outlined,
                onTap: () => _setQuickPrompt('Create a clear plan for '),
              ),
            ],
          ),

          const SizedBox(height: 32),

          const Text(
            '👋 Your AI Coach',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          const Text(
            'Day 1 of your 7-day journey',
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
            title: widget.plan.firstTask,
            subtitle: widget.plan.nextAction,
            time: '25 min',
            onStart: _openChat,
          ),

          const SizedBox(height: 22),

          _sectionCard(
            title: '🤖 Recommended AI',
            body: '${widget.plan.bestAI}\n\n${widget.plan.reason}',
          ),

          _sectionCard(
            title: '💬 AI Coach Message',
            body:
                "You don't need to finish everything today. "
                "Just complete today's mission. One step every day.",
          ),

          const SizedBox(height: 8),

          const Text(
            '📈 Your Journey',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          ...widget.plan.roadmap.map(_journeyItem),
        ],
      ),
    );
  }

  void _setQuickPrompt(String prompt) {
    _promptController.text = prompt;
    _promptController.selection = TextSelection.collapsed(
      offset: prompt.length,
    );
    _promptFocusNode.requestFocus();
  }

  Widget _sectionCard({required String title, required String body}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          '$title\n\n$body',
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

class _PromptComposer extends StatelessWidget {
  const _PromptComposer({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !isSending,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Ask AIOrbit anything...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) {
                  if (!isSending) {
                    onSend();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Send',
              onPressed: isSending ? null : onSend,
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_upward_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickPromptChip extends StatelessWidget {
  const _QuickPromptChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
