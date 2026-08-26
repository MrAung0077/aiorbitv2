import 'package:aiorbit/core/database/isar_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses Flutter debug mode for the default inspector setting', () {
    // `kDebugMode` is false for profile and release builds.
    expect(IsarService.defaultInspectorEnabled, kDebugMode);
  });
}
