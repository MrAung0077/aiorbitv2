import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conversation.dart';
import 'chat_controller.dart';

final conversationListProvider = FutureProvider<List<Conversation>>((
  ref,
) async {
  ref.watch(
    chatControllerProvider.select(
      (state) => (
        conversationId: state.conversation?.id,
        updatedAt: state.isBusy ? null : state.conversation?.updatedAt,
        isBusy: state.isBusy,
      ),
    ),
  );

  final repository = ref.watch(conversationRepositoryProvider);
  final conversations = await repository.getAllConversations();

  return orderConversationsByUpdatedAt(conversations);
});

List<Conversation> orderConversationsByUpdatedAt(
  Iterable<Conversation> conversations,
) {
  final ordered = conversations.toList(growable: false)
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  return List<Conversation>.unmodifiable(ordered);
}

List<Conversation> selectRecentConversations(
  List<Conversation> orderedConversations, {
  int limit = 5,
}) {
  if (orderedConversations.length <= 1 || limit <= 0) {
    return const <Conversation>[];
  }

  return orderedConversations.skip(1).take(limit).toList(growable: false);
}
