enum AIMessageRole { system, user, assistant }

class AIMessage {
  const AIMessage({required this.role, required this.content});

  final AIMessageRole role;
  final String content;

  Map<String, Object?> toJson() {
    return <String, Object?>{'role': role.name, 'content': content};
  }
}
