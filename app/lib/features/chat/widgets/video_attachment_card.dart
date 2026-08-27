import 'dart:io';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';

class VideoAttachmentCard extends StatelessWidget {
  const VideoAttachmentCard({super.key, required this.attachment});

  final ChatAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final version = attachment.artifactVersion;
    final available = File(attachment.localFilePath).existsSync();
    final fileName = version?.fileName?.trim();
    final byteSize = version?.byteSize;

    return Card(
      key: const ValueKey<String>('video-attachment-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            const Icon(Icons.video_file_outlined, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    available ? 'Video added' : 'Video unavailable',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (available && fileName != null && fileName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (available && byteSize != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(_formatByteSize(byteSize)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatByteSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).ceil()} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
