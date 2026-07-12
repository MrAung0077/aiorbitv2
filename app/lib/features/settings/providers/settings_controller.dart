import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_provider.dart';
import '../../../shared/models/app_setting.dart';
import '../../../shared/repositories/setting_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AsyncValue<AppSetting>>((ref) {
      return SettingsController(
        ref: ref,
        repository: ref.watch(settingsRepositoryProvider),
      );
    });

class SettingsController extends StateNotifier<AsyncValue<AppSetting>> {
  SettingsController({required Ref ref, required SettingsRepository repository})
    : _ref = ref,
      _repository = repository,
      super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;
  final SettingsRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();

    try {
      final settings = await _repository.getSettings();

      _applyTheme(settings.theme);
      _applyLocale(settings.language);

      state = AsyncValue.data(settings);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> setTheme(String theme) async {
    final settings = await _currentSettings();

    try {
      settings.theme = theme;
      await _repository.saveSettings(settings);

      _applyTheme(theme);
      state = AsyncValue.data(settings);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> setLanguage(String language) async {
    final settings = await _currentSettings();

    try {
      settings.language = language;
      await _repository.saveSettings(settings);

      _applyLocale(language);
      state = AsyncValue.data(settings);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<AppSetting> _currentSettings() async {
    final current = state.valueOrNull;

    if (current != null) {
      return current;
    }

    return _repository.getSettings();
  }

  void _applyTheme(String theme) {
    final notifier = _ref.read(themeModeProvider.notifier);

    switch (theme) {
      case 'light':
        notifier.setThemeMode(ThemeMode.light);
        break;
      case 'dark':
        notifier.setThemeMode(ThemeMode.dark);
        break;
      default:
        notifier.setThemeMode(ThemeMode.system);
    }
  }

  void _applyLocale(String language) {
    final notifier = _ref.read(localeProvider.notifier);

    switch (language) {
      case 'en':
        notifier.setLocale(const Locale('en'));
        break;
      case 'my':
        notifier.setLocale(const Locale('my'));
        break;
      default:
        notifier.useSystemLocale();
    }
  }
}
