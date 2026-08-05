import 'package:isar_community/isar.dart';

part 'mission_task_execution_record.g.dart';

@collection
class MissionTaskExecutionRecord {
  Id id = Isar.autoIncrement;

  @Index()
  String executionId = '';

  @Index()
  String missionId = '';

  @Index()
  String taskId = '';

  String status = '';

  double progress = 0.0;

  String? outputText;

  String? structuredResultReference;

  String? failureMessage;

  DateTime? startedAt;

  DateTime? finishedAt;

  DateTime updatedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
