/// A provider-neutral logical deliverable produced in a conversation.
///
/// An artifact can have multiple versions without replacing an earlier result.
class Artifact {
  const Artifact({
    required this.id,
    required this.conversationId,
    required this.type,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final ArtifactType type;
  final DateTime createdAt;
}

enum ArtifactType { image, audio, video, file }

/// A durable storage reference for one version of an [Artifact].
///
/// Local storage is used today. [remoteStorageKey] deliberately remains
/// provider-neutral so a later object-storage migration does not change the
/// Chat result shape.
class ArtifactVersion {
  const ArtifactVersion({
    required this.id,
    required this.artifactId,
    required this.mimeType,
    required this.localPath,
    required this.createdAt,
    this.remoteStorageKey,
    this.sourceArtifactVersionId,
    this.fileName,
    this.byteSize,
  });

  final String id;
  final String artifactId;
  final String mimeType;
  final String localPath;
  final String? remoteStorageKey;
  final String? sourceArtifactVersionId;
  final String? fileName;
  final int? byteSize;
  final DateTime createdAt;
}
