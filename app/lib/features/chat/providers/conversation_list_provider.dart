import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conversation.dart';
import 'chat_controller.dart';

final conversationSearchProvider = StateProvider<String>((ref) => '');

final conversationListProvider = FutureProvider<List<Conversation>>((
  ref,
) async {
  final repository = ref.watch(conversationRepositoryProvider);
  return repository.getAllConversations();
});
