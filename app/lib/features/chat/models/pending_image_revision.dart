/// Transient context for one prompt-based revision of a finished image.
class PendingImageRevision {
  const PendingImageRevision({
    required this.sourcePrompt,
    required this.sourceResultMessageId,
    required this.question,
    this.sourceMessageId,
    this.artifactId,
    this.artifactCreatedAt,
    this.sourceArtifactVersionId,
  });

  final String sourcePrompt;
  final String sourceResultMessageId;
  final String question;
  final String? sourceMessageId;
  final String? artifactId;
  final DateTime? artifactCreatedAt;
  final String? sourceArtifactVersionId;
}
