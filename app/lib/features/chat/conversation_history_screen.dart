import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/app_spacing.dart';
import 'ai_chat_screen.dart';
import 'providers/chat_controller.dart';
import 'providers/conversation_list_provider.dart';
import 'widgets/conversation_tile.dart';

class ConversationHistoryScreen extends ConsumerWidget {
  const ConversationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: conversations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _HistoryMessage(
          icon: Icons.error_outline_rounded,
          title: 'Could not load conversations',
          message: 'Please try again.',
        ),
        data: (items) {
          if (items.isEmpty) {
            return const _HistoryMessage(
              icon: Icons.forum_outlined,
              title: 'No conversations yet',
              message: 'Your conversations will appear here.',
            );
          }

          return ListView.separated(
            padding: AppSpacing.screen,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, index) {
              final conversation = items[index];

              return ConversationTile(
                conversation: conversation,
                onTap: () async {
                  final controller = ref.read(chatControllerProvider.notifier);

                  await controller.loadConversation(conversation.id);

                  if (!context.mounted ||
                      ref.read(chatControllerProvider).conversation?.id !=
                          conversation.id) {
                    return;
                  }

                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AIChatScreen(),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: AppSpacing.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
