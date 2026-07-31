import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/app_radius.dart';
import '../../core/design/app_spacing.dart';
import '../../core/widgets/app_prompt_composer.dart';
import '../chat/ai_chat_screen.dart';
import '../chat/providers/chat_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const String _heroTitle = 'One Prompt.';
  static const String _heroSubtitle = 'Best AI. Best Result.';
  static const String _heroQuestion = 'What do you want to accomplish today?';
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _promptFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    Future<void>.microtask(() async {
      if (!mounted) {
        return;
      }

      final chatState = ref.read(chatControllerProvider);

      if (chatState.conversation == null && !chatState.isLoading) {
        await ref
            .read(chatControllerProvider.notifier)
            .loadMostRecentConversation();
      }
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    _promptFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendPrompt() async {
    final prompt = _promptController.text.trim();
    final chatState = ref.read(chatControllerProvider);

    if (prompt.isEmpty || chatState.isBusy) {
      return;
    }

    final chatController = ref.read(chatControllerProvider.notifier);
    final conversationCreated = await chatController.createNewConversation();

    if (!mounted || !conversationCreated) {
      return;
    }

    _promptController.clear();
    _promptFocusNode.unfocus();

    await chatController.sendMessage(prompt);

    if (!mounted) {
      return;
    }

    await _openConversation();
  }

  Future<void> _openConversation() {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AIChatScreen()));
  }

  void _useQuickPrompt(String prompt) {
    _promptController.text = prompt;
    _promptController.selection = TextSelection.collapsed(
      offset: prompt.length,
    );
    _promptFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatState = ref.watch(chatControllerProvider);
    final activeConversation = chatState.conversation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ovexiq'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Account',
            onPressed: () {},
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: AppSpacing.screen,
              children: [
                const SizedBox(height: AppSpacing.lg),

                Text(
                  _heroTitle,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  (_heroSubtitle),
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                Text(
                  (_heroQuestion),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                AppPromptComposer(
                  controller: _promptController,
                  focusNode: _promptFocusNode,
                  isSending: chatState.isBusy,
                  onSend: _sendPrompt,
                ),

                const SizedBox(height: AppSpacing.xl),

                Text('Quick start', style: theme.textTheme.titleMedium),

                const SizedBox(height: AppSpacing.md),

                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _QuickAction(
                      icon: Icons.edit_outlined,
                      label: 'Write',
                      onTap: () => _useQuickPrompt('Help me write '),
                    ),
                    _QuickAction(
                      icon: Icons.code_rounded,
                      label: 'Code',
                      onTap: () =>
                          _useQuickPrompt('Help me build or fix this code: '),
                    ),
                    _QuickAction(
                      icon: Icons.search_rounded,
                      label: 'Research',
                      onTap: () =>
                          _useQuickPrompt('Research this topic for me: '),
                    ),
                    _QuickAction(
                      icon: Icons.analytics_outlined,
                      label: 'Analyze',
                      onTap: () => _useQuickPrompt('Analyze this for me: '),
                    ),
                    _QuickAction(
                      icon: Icons.translate_rounded,
                      label: 'Translate',
                      onTap: () => _useQuickPrompt('Translate this: '),
                    ),
                  ],
                ),

                if (activeConversation != null) ...[
                  const SizedBox(height: AppSpacing.xxl),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Continue',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: _openConversation,
                        child: const Text('Open'),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  Card(
                    clipBehavior: Clip.antiAlias,
                    margin: EdgeInsets.zero,
                    child: InkWell(
                      borderRadius: AppRadius.cardRadius,
                      onTap: _openConversation,
                      child: Padding(
                        padding: AppSpacing.card,
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activeConversation.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    activeConversation.preview,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.giant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
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
