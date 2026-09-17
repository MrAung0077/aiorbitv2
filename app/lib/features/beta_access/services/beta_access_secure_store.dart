import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class BetaAccessSecureStore {
  Future<String?> readDeviceSession();
  Future<void> writeDeviceSession(String value);
  Future<void> clearDeviceSession();
  Future<String?> readActivationId();
  Future<void> writeActivationId(String value);
}

class FlutterBetaAccessSecureStore implements BetaAccessSecureStore {
  FlutterBetaAccessSecureStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _deviceSessionKey = 'ovexiq.beta.device_session';
  static const _activationIdKey = 'ovexiq.beta.activation_id';

  final FlutterSecureStorage _storage;

  @override
  Future<void> clearDeviceSession() => _storage.delete(key: _deviceSessionKey);

  @override
  Future<String?> readActivationId() => _storage.read(key: _activationIdKey);

  @override
  Future<String?> readDeviceSession() => _storage.read(key: _deviceSessionKey);

  @override
  Future<void> writeActivationId(String value) =>
      _storage.write(key: _activationIdKey, value: value);

  @override
  Future<void> writeDeviceSession(String value) =>
      _storage.write(key: _deviceSessionKey, value: value);
}
