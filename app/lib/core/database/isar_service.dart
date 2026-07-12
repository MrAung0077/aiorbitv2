import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/chat/data/models/conversation_record.dart';
import '../../shared/models/app_setting.dart';

class IsarService {
  IsarService._();

  static Isar? _isar;

  static Future<void> initialize() async {
    if (_isar != null && _isar!.isOpen) {
      return;
    }

    final directory = await getApplicationDocumentsDirectory();

    _isar = await Isar.open(
      [AppSettingSchema, ConversationRecordSchema],
      directory: directory.path,
      name: 'aiorbit',
      inspector: true,
    );
  }

  static Isar get instance {
    final database = _isar;

    if (database == null || !database.isOpen) {
      throw StateError(
        'Isar has not been initialized. Call IsarService.initialize() first.',
      );
    }

    return database;
  }

  static Future<void> close() async {
    final database = _isar;

    if (database != null && database.isOpen) {
      await database.close();
    }

    _isar = null;
  }
}
