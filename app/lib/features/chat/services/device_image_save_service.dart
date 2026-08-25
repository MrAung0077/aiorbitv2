import 'package:flutter/services.dart';

/// Copies an already-generated local image into a user-visible device album.
abstract class DeviceImageSaveService {
  Future<bool> savePng({required String localFilePath});
}

class PlatformDeviceImageSaveService implements DeviceImageSaveService {
  PlatformDeviceImageSaveService({MethodChannel? channel})
    : _channel = channel ?? channelInstance;

  static const MethodChannel channelInstance = MethodChannel(
    'com.ovexiq.app/device_image_save',
  );

  final MethodChannel _channel;

  @override
  Future<bool> savePng({required String localFilePath}) async {
    if (localFilePath.trim().isEmpty) {
      return false;
    }

    try {
      return await _channel.invokeMethod<bool>('savePng', <String, Object>{
            'localFilePath': localFilePath,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
