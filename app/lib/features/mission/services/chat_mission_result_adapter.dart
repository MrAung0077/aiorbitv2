import '../models/mission.dart';
import '../models/task_status.dart';

class ChatMissionDeliverable {
  const ChatMissionDeliverable({required this.title, required this.content});

  final String title;
  final String content;
}

class ChatMissionResult {
  const ChatMissionResult({required this.deliverables});

  final List<ChatMissionDeliverable> deliverables;

  bool get isUsable => deliverables.isNotEmpty;
}

/// Adapts persisted accepted outputs for Chat without exposing orchestration
/// details such as task order, execution state, or progress.
class ChatMissionResultAdapter {
  const ChatMissionResultAdapter();

  ChatMissionResult? fromMission(Mission? mission) {
    if (mission == null) {
      return null;
    }

    final deliverables = <ChatMissionDeliverable>[];

    for (final task in mission.tasks) {
      final content = task.output?.trim();

      if (task.status != TaskStatus.completed || content?.isNotEmpty != true) {
        continue;
      }

      final title = task.title.trim();
      deliverables.add(
        ChatMissionDeliverable(
          title: title.isEmpty ? 'Result' : title,
          content: content!,
        ),
      );
    }

    if (deliverables.isEmpty) {
      return null;
    }

    return ChatMissionResult(
      deliverables: List<ChatMissionDeliverable>.unmodifiable(deliverables),
    );
  }
}
