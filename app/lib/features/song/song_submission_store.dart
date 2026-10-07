import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class SongSubmission {
  const SongSubmission({
    required this.scope,
    required this.requestJson,
    required this.createdAt,
    this.projectId,
  });

  factory SongSubmission.fromJson(Map<String, dynamic> json) => SongSubmission(
    scope: json['scope'] as String,
    requestJson: json['requestJson'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    projectId: json['projectId'] as String?,
  );

  final String scope;
  // Store the encoded snapshot so nested preferences cannot mutate after consent.
  final String requestJson;
  final DateTime createdAt;
  final String? projectId;
  String get requestId =>
      (jsonDecode(requestJson) as Map)['requestId'] as String;
  bool get acknowledged => projectId != null;
  Map<String, dynamic> get request =>
      jsonDecode(requestJson) as Map<String, dynamic>;
  SongSubmission acknowledge(String id) => SongSubmission(
    scope: scope,
    requestJson: requestJson,
    createdAt: createdAt,
    projectId: id,
  );
  Map<String, Object?> toJson() => {
    'version': 1,
    'scope': scope,
    'requestJson': requestJson,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'acknowledgement': acknowledged ? 'acknowledged' : 'pending',
    'projectId': projectId,
  };
}

abstract class SongSubmissionStore {
  Future<SongSubmission?> load(String scope);
  Future<void> save(SongSubmission submission);
}

// Append-only, flushed records avoid an overwrite gap during acknowledgement.
// A partial .tmp is ignored; corrupt published records fail closed.
class FileSongSubmissionStore implements SongSubmissionStore {
  FileSongSubmissionStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? getApplicationDocumentsDirectory;
  final Future<Directory> Function() _directoryProvider;

  Future<Directory> _folder(String scope) async {
    final root = await _directoryProvider();
    // Scope contains only the server origin and non-secret account reference.
    final name = base64Url.encode(utf8.encode(scope)).replaceAll('=', '');
    return Directory('${root.path}/song_submissions/$name');
  }

  Future<List<File>> _records(Directory directory) async {
    if (!await directory.exists()) return [];
    final records = await directory
        .list()
        .where(
          (entry) =>
              entry is File &&
              RegExp(r'[/\\]\d{16}\.json$').hasMatch(entry.path),
        )
        .cast<File>()
        .toList();
    records.sort((a, b) => a.path.compareTo(b.path));
    return records;
  }

  @override
  Future<SongSubmission?> load(String scope) async {
    final records = await _records(await _folder(scope));
    if (records.isEmpty) return null;
    final submission = SongSubmission.fromJson(
      jsonDecode(await records.last.readAsString()) as Map<String, dynamic>,
    );
    if (submission.scope != scope) {
      throw const FormatException('Submission scope mismatch');
    }
    return submission;
  }

  @override
  Future<void> save(SongSubmission submission) async {
    final directory = await _folder(submission.scope);
    await directory.create(recursive: true);
    final records = await _records(directory);
    final sequence = records.isEmpty
        ? 1
        : int.parse(records.last.uri.pathSegments.last.split('.').first) + 1;
    final finalPath =
        '${directory.path}/${sequence.toString().padLeft(16, '0')}.json';
    final temporary = File('$finalPath.tmp');
    await temporary.writeAsString(jsonEncode(submission.toJson()), flush: true);
    await temporary.rename(finalPath);
  }
}
