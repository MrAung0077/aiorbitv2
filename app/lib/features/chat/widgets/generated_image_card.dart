import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';

class GeneratedImageCard extends StatelessWidget {
  const GeneratedImageCard({
    super.key,
    required this.attachment,
    this.previewBytes,
  });

  final ChatAttachment attachment;
  final Uint8List? previewBytes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: const ValueKey<String>('generated-image-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Done', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: previewBytes == null
                  ? Image.file(
                      File(attachment.localFilePath),
                      key: const ValueKey<String>('generated-image-preview'),
                      fit: BoxFit.cover,
                      semanticLabel: 'Generated image',
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: colorScheme.surfaceContainerHighest,
                        child: const SizedBox(
                          height: 180,
                          child: Center(
                            child: Text('Image preview unavailable'),
                          ),
                        ),
                      ),
                    )
                  : Image.memory(
                      previewBytes!,
                      key: const ValueKey<String>('generated-image-preview'),
                      fit: BoxFit.cover,
                      semanticLabel: 'Generated image',
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: colorScheme.surfaceContainerHighest,
                        child: const SizedBox(
                          height: 180,
                          child: Center(
                            child: Text('Image preview unavailable'),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
