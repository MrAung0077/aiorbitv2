import 'package:aiorbit/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.validateStartupConfiguration', () {
    test('accepts a complete HTTPS production configuration', () {
      expect(
        () => AppConfig.validateStartupConfiguration(
          environment: 'production',
          apiBaseUrl: 'https://api.ovexiq.com',
          betaAccessToken: 'tester-token',
          isReleaseBuild: true,
        ),
        returnsNormally,
      );
    });

    test('rejects a production configuration without a gateway URL', () {
      const token = 'token-that-must-not-appear';

      expect(
        () => AppConfig.validateStartupConfiguration(
          environment: 'production',
          apiBaseUrl: '   ',
          betaAccessToken: token,
        ),
        throwsA(
          isA<AppConfigurationException>()
              .having(
                (error) => error.message,
                'message',
                contains('OVEXIQ_API_BASE_URL'),
              )
              .having(
                (error) => error.toString(),
                'does not expose token',
                isNot(contains(token)),
              ),
        ),
      );
    });

    test('rejects an HTTP production gateway URL', () {
      expect(
        () => AppConfig.validateStartupConfiguration(
          environment: 'production',
          apiBaseUrl: 'http://api.ovexiq.com',
          betaAccessToken: 'tester-token',
        ),
        throwsA(
          isA<AppConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('HTTPS URL'),
          ),
        ),
      );
    });

    test('rejects a production configuration without a beta token', () {
      expect(
        () => AppConfig.validateStartupConfiguration(
          environment: 'production',
          apiBaseUrl: 'https://api.ovexiq.com',
          betaAccessToken: '  ',
        ),
        throwsA(
          isA<AppConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('OVEXIQ_BETA_ACCESS_TOKEN'),
          ),
        ),
      );
    });

    test('keeps development builds usable without gateway credentials', () {
      expect(
        () => AppConfig.validateStartupConfiguration(
          environment: 'development',
          apiBaseUrl: '',
          betaAccessToken: '',
          isReleaseBuild: false,
        ),
        returnsNormally,
      );
    });

    test('rejects a release build that does not select production', () {
      expect(
        () => AppConfig.validateStartupConfiguration(
          environment: 'development',
          apiBaseUrl: '',
          betaAccessToken: '',
          isReleaseBuild: true,
        ),
        throwsA(
          isA<AppConfigurationException>().having(
            (error) => error.message,
            'message',
            'Release builds require APP_ENV=production.',
          ),
        ),
      );
    });
  });
}
