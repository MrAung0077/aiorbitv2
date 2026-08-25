import 'dart:convert';
import 'dart:typed_data';

import 'package:aiorbit/features/chat/models/chat_message.dart';
import 'package:aiorbit/features/chat/services/device_image_save_service.dart';
import 'package:aiorbit/features/chat/widgets/generated_image_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('saves a historic local image without generating another one', (
    tester,
  ) async {
    final saver = _FakeDeviceImageSaveService(saved: true);
    const attachment = ChatAttachment(
      id: 'historic-image',
      mimeType: 'image/png',
      localFilePath: '/private/ovexiq/historic-image.png',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GeneratedImageCard(
            attachment: attachment,
            previewBytes: _pngBytes(),
            onSaveImage: () =>
                saver.savePng(localFilePath: attachment.localFilePath),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('save-generated-image-button')),
    );
    await tester.pump();

    expect(saver.localFilePaths, <String>[attachment.localFilePath]);
    expect(find.text('Image saved'), findsOneWidget);
  });

  testWidgets('a missing local image shows a safe save failure', (
    tester,
  ) async {
    final saver = _FakeDeviceImageSaveService(saved: false);
    const attachment = ChatAttachment(
      id: 'missing-image',
      mimeType: 'image/png',
      localFilePath: '/private/ovexiq/missing-image.png',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GeneratedImageCard(
            attachment: attachment,
            previewBytes: _pngBytes(),
            onSaveImage: () =>
                saver.savePng(localFilePath: attachment.localFilePath),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('save-generated-image-button')),
    );
    await tester.pump();

    expect(saver.localFilePaths, <String>[attachment.localFilePath]);
    expect(find.text("Couldn't save image"), findsOneWidget);
  });

  testWidgets('shows Refine and waits for its callback without generating', (
    tester,
  ) async {
    var refineCount = 0;
    const attachment = ChatAttachment(
      id: 'refinable-image',
      mimeType: 'image/png',
      localFilePath: '/private/ovexiq/refinable-image.png',
      sourcePrompt: 'peaceful sunset over a mountain lake',
      sourceMessageId: 'source-message',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GeneratedImageCard(
            attachment: attachment,
            previewBytes: _pngBytes(),
            onRefineImage: () async {
              refineCount++;
              return true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Refine'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('refine-generated-image-button')),
    );
    await tester.pump();

    expect(refineCount, 1);
  });
}

Uint8List _pngBytes() {
  return base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
  );
}

class _FakeDeviceImageSaveService implements DeviceImageSaveService {
  _FakeDeviceImageSaveService({required this.saved});

  final bool saved;
  final List<String> localFilePaths = <String>[];

  @override
  Future<bool> savePng({required String localFilePath}) async {
    localFilePaths.add(localFilePath);
    return saved;
  }
}
