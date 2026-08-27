import 'dart:io';
import 'dart:typed_data';

import 'package:aiorbit/features/chat/services/local_video_ingest_service.dart';
import 'package:aiorbit/features/chat/services/video_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory documentsDirectory;

  setUp(() async {
    documentsDirectory = await Directory.systemTemp.createTemp(
      'ovexiq-video-ingest-',
    );
  });

  tearDown(() async {
    if (await documentsDirectory.exists()) {
      await documentsDirectory.delete(recursive: true);
    }
  });

  test('copies one valid video into Ovexiq-owned local storage', () async {
    final bytes = Uint8List.fromList(<int>[0, 1, 2, 3]);
    final service = LocalVideoIngestService(
      documentsDirectoryProvider: () async => documentsDirectory,
    );

    final result = await service.ingest(
      conversationId: 'conversation/1',
      ingestId: 'video/1',
      source: _selectedVideo(name: 'summer clip.MP4', bytes: bytes),
    );

    expect(result.mimeType, 'video/mp4');
    expect(result.fileName, 'summer clip.MP4');
    expect(result.byteSize, bytes.length);
    expect(result.localPath, contains('ovexiq_media'));
    expect(await File(result.localPath).readAsBytes(), bytes);
  });

  test(
    'rejects zero-byte, unsupported, and oversized video input safely',
    () async {
      final service = LocalVideoIngestService(
        documentsDirectoryProvider: () async => documentsDirectory,
      );

      await expectLater(
        service.ingest(
          conversationId: 'conversation',
          ingestId: 'zero',
          source: _selectedVideo(name: 'empty.mp4', bytes: Uint8List(0)),
        ),
        throwsA(isA<VideoIngestException>()),
      );
      await expectLater(
        service.ingest(
          conversationId: 'conversation',
          ingestId: 'unsupported',
          source: _selectedVideo(
            name: 'notes.txt',
            bytes: Uint8List.fromList(<int>[1]),
          ),
        ),
        throwsA(isA<VideoIngestException>()),
      );
      await expectLater(
        service.ingest(
          conversationId: 'conversation',
          ingestId: 'oversized',
          source: SelectedVideoFile(
            name: 'large.mov',
            readLength: () async => LocalVideoIngestService.maxVideoBytes + 1,
            readStream: () =>
                Stream<Uint8List>.value(Uint8List.fromList(<int>[1])),
          ),
        ),
        throwsA(isA<VideoIngestException>()),
      );
    },
  );
}

SelectedVideoFile _selectedVideo({
  required String name,
  required Uint8List bytes,
}) {
  return SelectedVideoFile(
    name: name,
    readLength: () async => bytes.length,
    readStream: () => Stream<Uint8List>.value(bytes),
  );
}
