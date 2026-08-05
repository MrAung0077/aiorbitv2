import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/chat/data/models/conversation_record.dart';
import '../../features/mission/data/models/mission_record.dart';
import '../../features/mission/data/models/mission_task_execution_record.dart';
import '../../shared/models/app_setting.dart';

class IsarService {
  IsarService._();

  static Isar? _isar;

  static Future<void> initialize({
    String? directoryPath,
    String name = 'aiorbit',
    bool inspector = true,
  }) async {
    if (_isar != null && _isar!.isOpen) {
      return;
    }

    final directory =
        directoryPath ?? (await getApplicationDocumentsDirectory()).path;

    _isar = await Isar.open(
      [
        AppSettingSchema,
        ConversationRecordSchema,
        MissionRecordSchema,
        MissionTaskExecutionRecordSchema,
      ],
      directory: directory,
      name: name,
      inspector: inspector,
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
