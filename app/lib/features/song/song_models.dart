import '../chat/models/artifact.dart';

enum VoiceIntent {
  generated('generated'),
  reusableIdentity('reusable_identity'),
  ownVoiceClone('own_voice_clone'),
  customLockedVoice('custom_locked_voice');

  const VoiceIntent(this.wireValue);
  final String wireValue;
  bool get needsPermission =>
      this == ownVoiceClone || this == customLockedVoice;

  String label(bool burmese) => switch (this) {
    generated =>
      burmese
          ? 'ဖန်တီးပေးသော အဆိုသံကို သုံးမည်'
          : 'Use the generated singing voice',
    reusableIdentity =>
      burmese
          ? 'သီချင်းများတွင် အဆိုတော်အသံတစ်သံတည်း ပြန်သုံးမည်'
          : 'Reuse the same singer across songs',
    ownVoiceClone =>
      burmese
          ? 'ကိုယ့်အသံကို အခြေခံ၍ ဖန်တီးမည်'
          : 'Use a clone of my own voice',
    customLockedVoice =>
      burmese
          ? 'အသုံးပြုခွင့်ရှိသော အသံတစ်သံကို သတ်မှတ်မည်'
          : 'Use a specific voice I have permission to use',
  };
}

enum SubtitlePreference { off, requested }

enum SongContext {
  singleSong('single_song'),
  reusableArtist('reusable_artist'),
  album('album');

  const SongContext(this.wireValue);
  final String wireValue;
}

class SongPreferences {
  const SongPreferences({
    this.voiceIntent = VoiceIntent.generated,
    this.subtitles = SubtitlePreference.off,
    this.context = SongContext.singleSong,
    this.style = '',
    this.userFinalLyrics,
    this.voicePermissionConfirmed = false,
  });
  factory SongPreferences.fromJson(Map<String, dynamic> json) =>
      SongPreferences(
        voiceIntent: VoiceIntent.values.firstWhere(
          (v) => v.wireValue == (json['voiceIntent'] ?? 'generated'),
        ),
        subtitles: SubtitlePreference.values.byName(
          json['subtitles'] as String? ?? 'off',
        ),
        context: SongContext.values.firstWhere(
          (v) => v.wireValue == (json['context'] ?? 'single_song'),
        ),
        style: json['style'] as String? ?? '',
        userFinalLyrics: json['userFinalLyrics'] as String?,
        voicePermissionConfirmed:
            json['voicePermissionConfirmed'] as bool? ?? false,
      );
  final VoiceIntent voiceIntent;
  final SubtitlePreference subtitles;
  final SongContext context;
  final String style;
  final String? userFinalLyrics;
  final bool voicePermissionConfirmed;
  Map<String, Object?> toJson() => {
    'voiceIntent': voiceIntent.wireValue,
    'subtitles': subtitles.name,
    'context': context.wireValue,
    'style': style.trim(),
    'userFinalLyrics': userFinalLyrics,
    'voicePermissionConfirmed': voicePermissionConfirmed,
  };
}

class SongArtifact {
  SongArtifact.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      fileName = json['fileName'] as String,
      mimeType = json['mimeType'] as String,
      byteSize = json['byteSize'] as int,
      sha256 = json['sha256'] as String {
    if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(id) ||
        !RegExp(r'^[a-z]+\.(mp3|mp4|txt)$').hasMatch(fileName) ||
        !['audio/mpeg', 'video/mp4', 'text/plain'].contains(mimeType) ||
        byteSize <= 0 ||
        byteSize > 256 * 1024 * 1024 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256)) {
      throw const FormatException('Invalid song artifact');
    }
  }
  final String id, fileName, mimeType, sha256;
  final int byteSize;
  ArtifactVersion version(String path, DateTime createdAt) => ArtifactVersion(
    id: id,
    artifactId: id,
    mimeType: mimeType,
    localPath: path,
    createdAt: createdAt,
    remoteStorageKey: id,
    fileName: fileName,
    byteSize: byteSize,
  );
}

class SongProject {
  SongProject.fromJson(Map<String, dynamic> json)
    : projectId = json['projectId'] as String,
      title = json['title'] as String,
      language = json['language'] as String,
      status = json['status'] as String,
      lyrics = json['lyrics'] as String,
      preferences = SongPreferences.fromJson(
        Map<String, dynamic>.from(json['preferences'] as Map? ?? {}),
      ),
      failureCode = (json['failure'] as Map?)?['code'] as String?,
      createdAt = DateTime.parse(json['createdAt'] as String),
      artifacts = (json['artifacts'] as List)
          .map(
            (a) => SongArtifact.fromJson(Map<String, dynamic>.from(a as Map)),
          )
          .toList() {
    if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(projectId) ||
        !['en', 'my'].contains(language) ||
        ![
          'queued',
          'specifying',
          'generating',
          'rendering',
          'completed',
          'failed',
          'interrupted',
        ].contains(status) ||
        (status == 'completed' &&
            artifacts.map((a) => a.fileName).toSet().intersection({
                  'lyrics.txt',
                  'song.mp3',
                  'youtube.mp4',
                  'teaser.mp4',
                }).length !=
                4)) {
      throw const FormatException('Invalid project');
    }
  }
  final String projectId, title, language, status, lyrics;
  final SongPreferences preferences;
  final String? failureCode;
  final DateTime createdAt;
  final List<SongArtifact> artifacts;
  bool get isActive =>
      ['queued', 'specifying', 'generating', 'rendering'].contains(status);
  bool get isComplete => status == 'completed' && artifacts.length == 4;
}

bool isOriginalSongRequest(String text) {
  final lower = text.toLowerCase();
  if (RegExp(
    r'\b(lyrics only|lyric ideas|song ideas|explain|how to)\b|စာသားပဲ|စာသားသာ|ရှင်းပြ',
  ).hasMatch(lower)) {
    return false;
  }
  return RegExp(r'\b(song|songs)\b|သီချင်း').hasMatch(lower) &&
      RegExp(
        r'\b(create|make|generate|compose|produce)\b|ဖန်တီး|လုပ်ပေး|ရေးပေး',
      ).hasMatch(lower);
}
