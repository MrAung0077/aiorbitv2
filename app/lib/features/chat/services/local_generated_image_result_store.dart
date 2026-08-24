import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

abstract class GeneratedImageResultStore {
  Future<String> savePng({
    required String conversationId,
    required String sourceMessageId,
    required Uint8List bytes,
  });
}

/// Stores generated image bytes outside Isar while leaving a small, durable
/// reference in the conversation message.
class LocalGeneratedImageResultStore implements GeneratedImageResultStore {
  LocalGeneratedImageResultStore({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectoryProvider;

  @override
  Future<String> savePng({
    required String conversationId,
    required String sourceMessageId,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'must not be empty');
    }

    final documentsDirectory = await _documentsDirectoryProvider();
    final imageDirectory = Directory(
      '${documentsDirectory.path}${Platform.pathSeparator}ovexiq_generated_images',
    );
    await imageDirectory.create(recursive: true);

    final fileName =
        '${_safeFilePart(conversationId)}-${_safeFilePart(sourceMessageId)}.png';
    final imageFile = File(
      '${imageDirectory.path}${Platform.pathSeparator}$fileName',
    );

    if (await imageFile.exists()) {
      return imageFile.path;
    }

    final temporaryFile = File('${imageFile.path}.tmp');
    await temporaryFile.writeAsBytes(bytes, flush: true);
    await temporaryFile.rename(imageFile.path);

    return imageFile.path;
  }

  String _safeFilePart(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return cleaned.isEmpty ? 'image' : cleaned;
  }
}
