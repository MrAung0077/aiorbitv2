import 'package:intl/intl.dart';

import 'execution_status.dart';
import 'mission.dart';
import 'mission_execution.dart';

class MissionTimeline {
  const MissionTimeline({required this.mission, this.execution});

  final Mission mission;
  final MissionExecution? execution;

  DateTime get createdAt => mission.createdAt;

  DateTime get updatedAt => mission.updatedAt;

  DateTime? get startedAt => _matchingExecution?.startedAt;

  DateTime? get completedAt {
    final currentExecution = _matchingExecution;

    if (currentExecution?.status != ExecutionStatus.completed) {
      return null;
    }

    return currentExecution?.finishedAt;
  }

  MissionExecution? get _matchingExecution {
    return execution?.missionId == mission.id ? execution : null;
  }
}

String formatMissionTimelineDate(
  DateTime? timestamp, {
  required String placeholder,
}) {
  if (timestamp == null) {
    return placeholder;
  }

  return DateFormat('MMM d, yyyy, h:mm a').format(timestamp.toLocal());
}
