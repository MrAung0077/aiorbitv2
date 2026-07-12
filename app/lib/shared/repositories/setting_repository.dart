import 'package:isar_community/isar.dart';

import '../../core/database/isar_service.dart';
import '../models/app_setting.dart';

class SettingsRepository {
  Isar get _isar => IsarService.instance;

  Future<AppSetting> getSettings() async {
    final existing = await _isar.appSettings.get(1);

    if (existing != null) {
      return existing;
    }

    final defaults = AppSetting()..id = 1;

    await _isar.writeTxn(() async {
      await _isar.appSettings.put(defaults);
    });

    return defaults;
  }

  Future<void> saveSettings(AppSetting settings) async {
    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });
  }

  Future<void> updateTheme(String theme) async {
    final settings = await getSettings();
    settings.theme = theme;
    await saveSettings(settings);
  }

  Future<void> updateLanguage(String language) async {
    final settings = await getSettings();
    settings.language = language;
    await saveSettings(settings);
  }

  Future<void> updateAIProvider(String aiProvider) async {
    final settings = await getSettings();
    settings.aiProvider = aiProvider;
    await saveSettings(settings);
  }
}
