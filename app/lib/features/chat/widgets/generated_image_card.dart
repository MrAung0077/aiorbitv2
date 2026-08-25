import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';

class GeneratedImageCard extends StatefulWidget {
  const GeneratedImageCard({
    super.key,
    required this.attachment,
    this.previewBytes,
    this.onSaveImage,
    this.onRefineImage,
    this.onRegenerateImage,
  });

  final ChatAttachment attachment;
  final Uint8List? previewBytes;
  final Future<bool> Function()? onSaveImage;
  final Future<bool> Function()? onRefineImage;
  final Future<bool> Function()? onRegenerateImage;

  @override
  State<GeneratedImageCard> createState() => _GeneratedImageCardState();
}

class _GeneratedImageCardState extends State<GeneratedImageCard> {
  var _isSaving = false;
  var _isRefining = false;
  var _isRegenerating = false;

  Future<void> _saveImage() async {
    if (_isSaving || widget.onSaveImage == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    var saved = false;
    try {
      saved = await widget.onSaveImage!();
    } catch (_) {
      saved = false;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(saved ? 'Image saved' : "Couldn't save image")),
      );
  }

  Future<void> _refineImage() async {
    if (_isRefining || widget.onRefineImage == null) {
      return;
    }

    setState(() {
      _isRefining = true;
    });

    try {
      await widget.onRefineImage!();
    } finally {
      if (mounted) {
        setState(() {
          _isRefining = false;
        });
      }
    }
  }

  Future<void> _regenerateImage() async {
    if (_isRegenerating || widget.onRegenerateImage == null) {
      return;
    }

    setState(() {
      _isRegenerating = true;
    });

    var started = false;
    try {
      started = await widget.onRegenerateImage!();
    } catch (_) {
      started = false;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isRegenerating = false;
    });

    if (!started) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text("Couldn't regenerate image")),
        );
    }
  }

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
              child: widget.previewBytes == null
                  ? Image.file(
                      File(widget.attachment.localFilePath),
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
                      widget.previewBytes!,
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
            if (widget.onSaveImage != null ||
                widget.onRefineImage != null ||
                widget.onRegenerateImage != null) ...<Widget>[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 4,
                  children: <Widget>[
                    if (widget.onRefineImage != null)
                      TextButton.icon(
                        key: const ValueKey<String>(
                          'refine-generated-image-button',
                        ),
                        onPressed: _isRefining ? null : _refineImage,
                        icon: const Icon(Icons.tune_outlined),
                        label: const Text('Refine'),
                      ),
                    if (widget.onRegenerateImage != null)
                      TextButton.icon(
                        key: const ValueKey<String>(
                          'regenerate-generated-image-button',
                        ),
                        onPressed: _isRegenerating ? null : _regenerateImage,
                        icon: const Icon(Icons.refresh_outlined),
                        label: const Text('Regenerate'),
                      ),
                    if (widget.onSaveImage != null)
                      TextButton.icon(
                        key: const ValueKey<String>(
                          'save-generated-image-button',
                        ),
                        onPressed: _isSaving ? null : _saveImage,
                        icon: const Icon(Icons.download_outlined),
                        label: Text(_isSaving ? 'Saving...' : 'Save Image'),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
