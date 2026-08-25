import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/device_image_save_service.dart';

final deviceImageSaveServiceProvider = Provider<DeviceImageSaveService>((ref) {
  return PlatformDeviceImageSaveService();
});
