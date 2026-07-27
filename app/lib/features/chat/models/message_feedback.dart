enum MessageFeedback { none, liked, disliked }

class MessageFeedbackRecord {
  const MessageFeedbackRecord({
    required this.messageId,
    required this.feedback,
  });

  final String messageId;
  final MessageFeedback feedback;

  MessageFeedbackRecord copyWith({
    String? messageId,
    MessageFeedback? feedback,
  }) {
    return MessageFeedbackRecord(
      messageId: messageId ?? this.messageId,
      feedback: feedback ?? this.feedback,
    );
  }
}
