import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_video_ingest_service.dart';
import '../services/video_picker.dart';

final videoPickerProvider = Provider<VideoPicker>((ref) {
  return const SystemVideoPicker();
});

final localVideoIngestServiceProvider = Provider<LocalVideoIngestService>((
  ref,
) {
  return LocalVideoIngestService();
});
