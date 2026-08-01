import 'package:isar_community/isar.dart';

part 'mission_task_record.g.dart';

@embedded
class MissionTaskRecord {
  String taskId = '';

  String missionId = '';

  String title = '';

  String description = '';

  int order = 0;

  String status = 'pending';

  String taskType = '';

  String? recommendedProvider;

  String? inputContext;

  DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  DateTime? completedAt;
}
