import 'package:isar_community/isar.dart';

import 'mission_task_record.dart';

part 'mission_record.g.dart';

@collection
class MissionRecord {
  Id id = Isar.autoIncrement;

  @Index()
  String missionId = '';

  @Index()
  String? conversationId;

  String title = '';

  String goal = '';

  String category = 'custom';

  String status = 'draft';

  DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  DateTime updatedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  int currentTaskIndex = 0;

  List<MissionTaskRecord> tasks = <MissionTaskRecord>[];

  String? userContext;
}
