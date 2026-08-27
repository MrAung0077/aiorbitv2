import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// A single user-selected video. Its content is read only long enough to copy
/// it into Ovexiq-owned storage.
class SelectedVideoFile {
  const SelectedVideoFile({
    required this.name,
    required this.readLength,
    required this.readStream,
  });

  final String name;
  final Future<int> Function() readLength;
  final Stream<Uint8List> Function() readStream;
}

abstract interface class VideoPicker {
  Future<SelectedVideoFile?> pickOneVideo();
}

/// Uses the operating system's single-file picker. Android grants access only
/// to the video the person selected, so no broad storage permission is needed.
class SystemVideoPicker implements VideoPicker {
  const SystemVideoPicker();

  @override
  Future<SelectedVideoFile?> pickOneVideo() async {
    final file = await FilePicker.pickFile(type: FileType.video);
    if (file == null) {
      return null;
    }

    return SelectedVideoFile(
      name: file.name,
      readLength: file.length,
      readStream: file.readAsByteStream,
    );
  }
}
