import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_config.dart';
import '../beta_access/providers/beta_access_provider.dart';
import 'song_models.dart';

class SongFailure implements Exception {
  const SongFailure(this.code);
  final String code;
  @override
  String toString() => 'Song workflow unavailable';
}

final songApiProvider = Provider<SongApi>((ref) {
  final access = ref.read(betaAccessControllerProvider.notifier);
  final api = SongApi(
    baseUrl: AppConfig.ovexiqApiBaseUrl,
    token: AppConfig.ovexiqBetaAccessToken,
    session: () => access.deviceSession,
    invalidateSession: access.invalidateSession,
  );
  ref.onDispose(api.close);
  return api;
});

class SongApi {
  SongApi({
    required String baseUrl,
    required String token,
    required this.session,
    required this.invalidateSession,
    http.Client? client,
  }) : _base = Uri.tryParse(baseUrl),
       // Keep the public named constructor argument and private backing field.
       // ignore: prefer_initializing_formals
       _token = token,
       _client = client ?? http.Client();
  final Uri? _base;
  final String _token;
  final String? Function() session;
  final Future<void> Function() invalidateSession;
  final http.Client _client;
  void close() => _client.close();
  Uri _uri(String path) {
    if (_base?.scheme != 'https' || _base!.host.isEmpty) {
      throw const SongFailure('not_configured');
    }
    return _base.resolve('/v1/media/$path');
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'X-Ovexiq-Beta-Token': _token,
    'X-Ovexiq-Device-Session': session() ?? '',
  };
  Future<void> _check(int status) async {
    if (status == 401) {
      await invalidateSession();
      throw const SongFailure('unauthorized');
    }
    if (status < 200 || status >= 300) {
      throw SongFailure(
        status == 429
            ? 'rate_limited'
            : status == 403
            ? 'not_enabled'
            : 'request_failed',
      );
    }
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Object? body,
  ]) async {
    try {
      final request = http.Request(method, _uri(path))
        ..headers.addAll(_headers);
      if (body != null) request.body = jsonEncode(body);
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 60));
      await _check(response.statusCode);
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 60),
      )) {
        if (bytes.length + chunk.length > 2 * 1024 * 1024) {
          throw const SongFailure('invalid_response');
        }
        bytes.addAll(chunk);
      }
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } on SongFailure {
      rethrow;
    } catch (_) {
      throw const SongFailure('connection');
    }
  }

  Future<List<SongProject>> projects() async =>
      ((await request('GET', 'projects'))['projects'] as List)
          .map((p) => SongProject.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList();
  Future<Map<String, dynamic>> artist() => request('GET', 'artist');
  Future<void> saveArtist(String name, List<String> ids) async {
    await request('PUT', 'artist', {
      'artistName': name,
      'visualReferenceIds': ids,
    });
  }

  Future<String> uploadVisual(Uint8List bytes, String mimeType) async {
    if (bytes.length > 8 * 1024 * 1024) {
      throw const SongFailure('image_too_large');
    }
    return (await request('POST', 'visuals', {
          'data': base64Encode(bytes),
          'mimeType': mimeType,
        }))['id']
        as String;
  }

  Future<SongProject> create(
    String goal,
    String language,
    String requestId,
  ) async => SongProject.fromJson(
    await request('POST', 'projects', {
      'goal': goal,
      'language': language,
      'requestId': requestId,
    }),
  );

  Future<String> download(SongProject project, SongArtifact artifact) async {
    File? partial;
    IOSink? sink;
    try {
      final root = await getApplicationDocumentsDirectory();
      final folder = Directory(
        '${root.path}/song_artifacts/${project.projectId}',
      );
      await folder.create(recursive: true);
      final file = File('${folder.path}/${artifact.fileName}');
      // Always revalidate downloaded bytes natively before opening/saving/sharing.
      if (await file.exists()) {
        if (await file.length() == artifact.byteSize &&
            await SongDeviceFiles().perform('verify', file.path, artifact)) {
          return file.path;
        }
        await file.delete(); // Only this app-owned corrupt cache entry.
      }
      partial = File('${file.path}.part');
      final request = http.Request(
        'GET',
        _uri('projects/${project.projectId}/artifacts/${artifact.id}'),
      )..headers.addAll(_headers);
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 60));
      await _check(response.statusCode);
      if (response.headers['content-type']?.split(';').first !=
          artifact.mimeType) {
        throw const SongFailure('invalid_artifact');
      }
      sink = partial.openWrite();
      var size = 0;
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 60),
      )) {
        size += chunk.length;
        if (size > artifact.byteSize) {
          throw const SongFailure('invalid_artifact');
        }
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (size != artifact.byteSize) {
        throw const SongFailure('invalid_artifact');
      }
      if (!await SongDeviceFiles().perform('verify', partial.path, artifact)) {
        throw const SongFailure('invalid_artifact');
      }
      await partial.rename(file.path);
      return file.path;
    } on SongFailure {
      rethrow;
    } catch (_) {
      throw const SongFailure('download_failed');
    } finally {
      await sink?.close();
      if (partial != null && await partial.exists()) await partial.delete();
    }
  }
}

class SongDeviceFiles {
  static const channel = MethodChannel('com.ovexiq.app/song_files');
  Future<bool> perform(
    String action,
    String path,
    SongArtifact artifact,
  ) async {
    try {
      return await channel.invokeMethod<bool>(action, {
            'path': path,
            'mimeType': artifact.mimeType,
            'fileName': artifact.fileName,
            'sha256': artifact.sha256,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }
}

String newSongRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final text = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${text.substring(0, 8)}-${text.substring(8, 12)}-${text.substring(12, 16)}-${text.substring(16, 20)}-${text.substring(20)}';
}
