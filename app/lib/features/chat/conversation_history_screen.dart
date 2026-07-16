import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/app_spacing.dart';
import 'providers/chat_controller.dart';
import 'providers/conversation_list_provider.dart';
import 'widgets/conversation_tile.dart';

class ConversationHistoryScreen extends ConsumerWidget {
  const ConversationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationListProvider);
    final searchQuery = ref.watch(conversationSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search conversations...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                ref.read(conversationSearchProvider.notifier).state = value;
              },
            ),
          ),
        ),
      ),
      body: conversations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (items) {
          final normalizedQuery = searchQuery.trim().toLowerCase();

          final filteredItems = items
              .where((conversation) {
                if (normalizedQuery.isEmpty) {
                  return true;
                }

                return conversation.title.toLowerCase().contains(
                      normalizedQuery,
                    ) ||
                    conversation.preview.toLowerCase().contains(
                      normalizedQuery,
                    );
              })
              .toList(growable: false);

          if (items.isEmpty) {
            return const Center(child: Text('No conversations yet'));
          }

          if (filteredItems.isEmpty) {
            return const Center(child: Text('No matching conversations'));
          }

          return ListView.separated(
            padding: AppSpacing.screen,
            itemCount: filteredItems.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final conversation = filteredItems[index];

              return Dismissible(
                key: ValueKey(conversation.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) {
                          return AlertDialog(
                            title: const Text('Delete conversation?'),
                            content: const Text(
                              'This conversation will be permanently removed.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext, false);
                                },
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext, true);
                                },
                                child: const Text('Delete'),
                              ),
                            ],
                          );
                        },
                      ) ??
                      false;
                },
                onDismissed: (_) async {
                  final repository = ref.read(conversationRepositoryProvider);

                  await repository.deleteConversation(conversation.id);

                  ref.invalidate(conversationListProvider);

                  if (!context.mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Conversation deleted')),
                  );
                },
                child: ConversationTile(
                  conversation: conversation,
                  onTap: () async {
                    await ref
                        .read(chatControllerProvider.notifier)
                        .loadConversation(conversation.id);

                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
