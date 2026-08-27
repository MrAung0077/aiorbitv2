import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'video_picker.dart';

class VideoIngestException implements Exception {
  const VideoIngestException();
}

class IngestedVideo {
  const IngestedVideo({
    required this.fileName,
    required this.mimeType,
    required this.localPath,
    required this.byteSize,
  });

  final String fileName;
  final String mimeType;
  final String localPath;
  final int byteSize;
}

/// Copies one selected video into Ovexiq-owned storage before the original
/// picker grant or temporary file can disappear.
class LocalVideoIngestService {
  LocalVideoIngestService({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  static const int maxVideoBytes = 250 * 1024 * 1024;

  final Future<Directory> Function() _documentsDirectoryProvider;

  Future<IngestedVideo> ingest({
    required String conversationId,
    required String ingestId,
    required SelectedVideoFile source,
  }) async {
    final fileName = source.name.trim();
    final mimeType = _mimeTypeFor(fileName);
    final reportedSize = await source.readLength();
    if (fileName.isEmpty ||
        mimeType == null ||
        reportedSize <= 0 ||
        reportedSize > maxVideoBytes) {
      throw const VideoIngestException();
    }

    final documentsDirectory = await _documentsDirectoryProvider();
    final videoDirectory = Directory(
      '${documentsDirectory.path}${Platform.pathSeparator}ovexiq_media'
      '${Platform.pathSeparator}videos',
    );
    await videoDirectory.create(recursive: true);

    final extension = fileName.substring(fileName.lastIndexOf('.') + 1);
    final safeName =
        '${_safeFilePart(conversationId)}-${_safeFilePart(ingestId)}.$extension';
    final destination = File(
      '${videoDirectory.path}${Platform.pathSeparator}$safeName',
    );
    final temporary = File('${destination.path}.tmp');

    try {
      if (await destination.exists()) {
        final existingSize = await destination.length();
        if (existingSize > 0 && existingSize <= maxVideoBytes) {
          return IngestedVideo(
            fileName: fileName,
            mimeType: mimeType,
            localPath: destination.path,
            byteSize: existingSize,
          );
        }
        await destination.delete();
      }

      var copiedBytes = 0;
      final sink = temporary.openWrite();
      try {
        await for (final chunk in source.readStream()) {
          copiedBytes += chunk.length;
          if (copiedBytes > maxVideoBytes) {
            throw const VideoIngestException();
          }
          sink.add(chunk);
        }
        await sink.close();
      } catch (_) {
        await sink.close();
        rethrow;
      }

      if (copiedBytes <= 0 || copiedBytes != reportedSize) {
        throw const VideoIngestException();
      }
      await temporary.rename(destination.path);
      return IngestedVideo(
        fileName: fileName,
        mimeType: mimeType,
        localPath: destination.path,
        byteSize: copiedBytes,
      );
    } catch (_) {
      if (await temporary.exists()) {
        await temporary.delete();
      }
      rethrow;
    }
  }

  String? _mimeTypeFor(String fileName) {
    final extension = fileName.split('.').last.trim().toLowerCase();
    return switch (extension) {
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'm4v' => 'video/x-m4v',
      'webm' => 'video/webm',
      '3gp' || '3gpp' => 'video/3gpp',
      _ => null,
    };
  }

  String _safeFilePart(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return cleaned.isEmpty ? 'video' : cleaned;
  }
}
