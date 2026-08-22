enum ChatClarificationIntent { facebookPost, tiktokVideos }

class PendingChatClarification {
  const PendingChatClarification({
    required this.originalPrompt,
    required this.question,
    required this.intent,
    required this.requiredField,
  });

  final String originalPrompt;
  final String question;
  final ChatClarificationIntent intent;
  final String requiredField;
}
