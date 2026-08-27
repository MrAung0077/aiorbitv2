import 'dart:io';

import 'package:aiorbit/features/chat/models/artifact.dart';
import 'package:aiorbit/features/chat/models/chat_message.dart';
import 'package:aiorbit/features/chat/widgets/video_attachment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders persisted video metadata without showing a path', (
    tester,
  ) async {
    final file = File(Platform.resolvedExecutable);
    final attachment = ChatAttachment(
      id: 'video-result',
      mimeType: 'video/mp4',
      localFilePath: file.path,
      artifact: Artifact(
        id: 'video-artifact',
        conversationId: 'conversation',
        type: ArtifactType.video,
        createdAt: DateTime(2026, 8, 26),
      ),
      artifactVersion: ArtifactVersion(
        id: 'video-version',
        artifactId: 'video-artifact',
        mimeType: 'video/mp4',
        localPath: file.path,
        fileName: 'summer.mp4',
        byteSize: 4,
        createdAt: DateTime(2026, 8, 26),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VideoAttachmentCard(attachment: attachment)),
      ),
    );

    expect(find.text('Video added'), findsOneWidget);
    expect(find.text('summer.mp4'), findsOneWidget);
    expect(find.text('1 KB'), findsOneWidget);
    expect(find.text(file.path), findsNothing);
  });

  testWidgets('shows a safe unavailable state for a missing local video', (
    tester,
  ) async {
    const attachment = ChatAttachment(
      id: 'missing-video',
      mimeType: 'video/mp4',
      localFilePath: 'Z:/missing/video.mp4',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VideoAttachmentCard(attachment: attachment)),
      ),
    );

    expect(find.text('Video unavailable'), findsOneWidget);
  });
}
