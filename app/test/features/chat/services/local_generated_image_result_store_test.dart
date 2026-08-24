import 'dart:io';
import 'dart:typed_data';

import 'package:aiorbit/features/chat/services/local_generated_image_result_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('writes one stable local PNG file without rewriting it', () async {
    final directory = await Directory.systemTemp.createTemp(
      'aiorbit-generated-image-store-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = LocalGeneratedImageResultStore(
      documentsDirectoryProvider: () async => directory,
    );

    final path = await store.savePng(
      conversationId: 'conversation:1',
      sourceMessageId: 'message/1',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    );
    final repeatedPath = await store.savePng(
      conversationId: 'conversation:1',
      sourceMessageId: 'message/1',
      bytes: Uint8List.fromList(<int>[9, 9, 9]),
    );

    expect(repeatedPath, path);
    expect(File(path).existsSync(), isTrue);
    expect(await File(path).readAsBytes(), <int>[1, 2, 3]);
    expect(path, contains('conversation_1-message_1.png'));
  });
}
