import 'package:aiorbit/features/chat/services/device_image_save_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = PlatformDeviceImageSaveService.channelInstance;

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('passes the persisted local PNG to the device save handler', () async {
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return true;
        });

    final saved = await PlatformDeviceImageSaveService().savePng(
      localFilePath: '/private/ovexiq/generated-image.png',
    );

    expect(saved, isTrue);
    expect(receivedCall?.method, 'savePng');
    expect(receivedCall?.arguments, <String, Object>{
      'localFilePath': '/private/ovexiq/generated-image.png',
    });
  });

  test('returns a safe failure when the device save handler fails', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'save-failed', message: 'raw failure');
        });

    final saved = await PlatformDeviceImageSaveService().savePng(
      localFilePath: '/private/ovexiq/missing-image.png',
    );

    expect(saved, isFalse);
  });
}
