import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/app_radius.dart';
import '../../core/design/app_spacing.dart';
import '../../core/widgets/app_prompt_composer.dart';
import '../chat/ai_chat_screen.dart';
import '../chat/models/conversation.dart';
import '../chat/providers/chat_controller.dart';
import '../chat/providers/conversation_list_provider.dart';
import '../chat/widgets/conversation_tile.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const String _heroTitle = 'Ovexiq';
  static const String _heroSubtitle = 'AI tools for getting work done';
  static const String _heroQuestion =
      'Start with a goal, a draft, or a task you want to finish.';
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

    final conversation = ref.read(chatControllerProvider).conversation;

    if (!mounted || conversation == null) {
      return;
    }

    await _openConversation(conversation, reload: false);

    // Do not leave the user on Home while a normal text completion is pending.
    // The destination observes this controller state, including an image action
    // emitted before its first frame.
    unawaited(chatController.sendMessage(prompt));
  }

  Future<void> _openConversation(
    Conversation conversation, {
    bool reload = true,
  }) async {
    if (reload) {
      await ref
          .read(chatControllerProvider.notifier)
          .loadConversation(conversation.id);
    }

    if (!mounted ||
        ref.read(chatControllerProvider).conversation?.id != conversation.id) {
      return;
    }

    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AIChatScreen())),
    );
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
    final conversationList = ref.watch(conversationListProvider);
    final conversations =
        conversationList.asData?.value ?? const <Conversation>[];
    final hasConversationLoadError = conversationList.hasError;
    final continueConversation = conversations.isEmpty
        ? null
        : conversations.first;
    final recentConversations = selectRecentConversations(conversations);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ovexiq'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: AppSpacing.screen,
              children: [
                const SizedBox(height: AppSpacing.sm),

                Text(
                  _heroTitle,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _heroSubtitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                Text(
                  (_heroQuestion),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                AppPromptComposer(
                  controller: _promptController,
                  focusNode: _promptFocusNode,
                  isSending: chatState.isBusy,
                  onSend: _sendPrompt,
                ),

                const SizedBox(height: AppSpacing.xl),

                Text('Creator tools', style: theme.textTheme.titleMedium),

                const SizedBox(height: AppSpacing.md),

                GridView.count(
                  crossAxisCount: MediaQuery.sizeOf(context).width < 390 ? 2 : 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.48,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  children: [
                    _ToolCard(
                      icon: Icons.dashboard_customize_outlined,
                      title: 'Content Kit',
                      subtitle: 'Plan a complete content set',
                      onTap: () => _useQuickPrompt('Create a content kit for '),
                    ),
                    _ToolCard(
                      icon: Icons.movie_filter_outlined,
                      title: 'Reel Script',
                      subtitle: 'Script, hook and shot list',
                      onTap: () => _useQuickPrompt('Write a Reel script for '),
                    ),
                    _ToolCard(
                      icon: Icons.image_outlined,
                      title: 'Image',
                      subtitle: 'Create or refine an image',
                      onTap: () => _useQuickPrompt('Create an image of '),
                    ),
                    _ToolCard(
                      icon: Icons.videocam_outlined,
                      title: 'Video',
                      subtitle: 'Video tools',
                      isAvailable: false,
                    ),
                    _ToolCard(
                      icon: Icons.travel_explore_outlined,
                      title: 'Research',
                      subtitle: 'Explore a topic clearly',
                      onTap: () => _useQuickPrompt('Research this for me: '),
                    ),
                    _ToolCard(
                      icon: Icons.closed_caption_outlined,
                      title: 'Caption',
                      subtitle: 'Captions and translation',
                      onTap: () => _useQuickPrompt('Write a caption for '),
                    ),
                  ],
                ),

                if (hasConversationLoadError) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  _ConversationHistoryErrorCard(
                    onRetry: () {
                      ref.invalidate(conversationListProvider);
                    },
                  ),
                ] else if (continueConversation != null) ...[
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
                        onPressed: () {
                          _openConversation(continueConversation);
                        },
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
                      onTap: () {
                        _openConversation(continueConversation);
                      },
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
                                    continueConversation.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    continueConversation.preview,
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

                  if (recentConversations.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    Text('Recent', style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    ...recentConversations.indexed.map((entry) {
                      final index = entry.$1;
                      final conversation = entry.$2;

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == recentConversations.length - 1
                              ? 0
                              : AppSpacing.md,
                        ),
                        child: ConversationTile(
                          conversation: conversation,
                          onTap: () {
                            _openConversation(conversation);
                          },
                        ),
                      );
                    }),
                  ],
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

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.isAvailable = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        key: ValueKey<String>('tool-card-$title'),
        borderRadius: AppRadius.cardRadius,
        onTap: isAvailable ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isAvailable
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const Spacer(),
                  if (!isAvailable)
                    Text(
                      'Coming soon',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationHistoryErrorCard extends StatelessWidget {
  const _ConversationHistoryErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Could not load conversations',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Please try again.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
