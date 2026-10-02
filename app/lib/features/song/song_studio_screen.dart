import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/text/response_language.dart';
import 'song_api.dart';
import 'song_models.dart';

class SongStudioScreen extends ConsumerStatefulWidget {
  const SongStudioScreen({super.key, this.initialGoal = ''});
  final String initialGoal;
  @override
  ConsumerState<SongStudioScreen> createState() => _SongStudioScreenState();
}

class _SongStudioScreenState extends ConsumerState<SongStudioScreen> {
  late final TextEditingController _goal = TextEditingController(
    text: widget.initialGoal,
  );
  final _artistName = TextEditingController(text: 'Ari');
  late String _language =
      responseLanguageFor(widget.initialGoal) == ResponseLanguage.burmese
      ? 'my'
      : 'en';
  List<String> _visualIds = [];
  List<SongProject> _projects = [];
  Timer? _poll;
  bool _busy = false, _loading = true, _rightsConfirmed = false;
  String? _error, _requestId, _pendingGoal;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _goal.dispose();
    _artistName.dispose();
    super.dispose();
  }

  String tr(String en, String my) => _language == 'my' ? my : en;
  Future<void> _load() async {
    _poll?.cancel();
    try {
      final api = ref.read(songApiProvider);
      final artist = await api.artist();
      final projects = await api.projects();
      if (!mounted) return;
      setState(() {
        _artistName.text = artist['artistName'] as String;
        _visualIds = List<String>.from(artist['visualReferenceIds'] as List);
        _projects = projects;
        _loading = false;
        _error = null;
      });
      if (projects.any((p) => p.isActive)) {
        _poll = Timer(const Duration(seconds: 5), () => unawaited(_load()));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = tr(
            'Song service could not be reached or is not enabled for this account. No job is started by refreshing.',
            'သီချင်းဝန်ဆောင်မှုကို ဆက်သွယ်၍ မရသေးပါ။ ပြန်ဖွင့်ကြည့်ရုံဖြင့် သီချင်းအသစ် မဖန်တီးပါ။',
          );
        });
      }
    }
  }

  Future<void> _visuals() async {
    setState(() => _busy = true);
    try {
      final selected = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );
      if (selected.isEmpty) return;
      if (selected.length != 4) throw const SongFailure('four_images_required');
      final ids = <String>[];
      final api = ref.read(songApiProvider);
      for (final file in selected) {
        if (await file.length() > 8 * 1024 * 1024) {
          throw const SongFailure('image_too_large');
        }
        ids.add(
          await api.uploadVisual(
            await file.readAsBytes(),
            file.name.toLowerCase().endsWith('.png')
                ? 'image/png'
                : 'image/jpeg',
          ),
        );
      }
      await api.saveArtist(_artistName.text.trim(), ids);
      if (mounted) setState(() => _visualIds = ids);
    } catch (_) {
      if (mounted) {
        _notice(
          tr(
            'Select four JPG/PNG images, each under 8 MB. Upload did not complete.',
            'JPG/PNG ပုံ ၄ ပုံ ရွေးပေးပါ။ တစ်ပုံလျှင် 8 MB အောက် ဖြစ်ရပါမည်။ ပုံတင်ခြင်း မပြီးသေးပါ။',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    if (_busy ||
        _visualIds.length != 4 ||
        !_rightsConfirmed ||
        _goal.text.trim().length < 8) {
      return;
    }
    final goal = _goal.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Create this song?', 'သီချင်းဖန်တီးမလား။')),
        content: Text(
          tr(
            'This starts one paid song-spec request and one music generation. No automatic paid retry. Your four artist images will be used for both videos.',
            'သီချင်းအစီအစဉ်နှင့် သီချင်းအသံ ဖန်တီးရန် အခကြေးငွေရှိသော တောင်းဆိုမှု တစ်ကြိမ်စီ ပြုလုပ်ပါမည်။ အလိုအလျောက် ထပ်မလုပ်ပါ။ ဗီဒီယိုနှစ်ခုလုံးတွင် ရွေးထားသော အဆိုတော်ပုံ ၄ ပုံကို သုံးပါမည်။',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Not now', 'မလုပ်သေးပါ')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Create', 'ဖန်တီးမည်')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    // Retain the id across transport failures. Explicit retries cannot submit a
    // second paid job for the same in-screen request.
    final fingerprint = '$_language:$goal';
    if (_pendingGoal != fingerprint) {
      _requestId = newSongRequestId();
      _pendingGoal = fingerprint;
    }
    try {
      await ref.read(songApiProvider).create(goal, _language, _requestId!);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tr(
            'Submission was not confirmed. Refresh projects first. Retrying this unchanged request reuses its job ID.',
            'တောင်းဆိုမှု လက်ခံရရှိကြောင်း မသေချာသေးပါ။ သိမ်းထားသော သီချင်းများကို အရင် ပြန်ဖွင့်ကြည့်ပါ။ မပြောင်းထားသော တောင်းဆိုမှုကို ထပ်ပို့လျှင် မူလအမှတ်အသားကိုသာ သုံးပါမည်။',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _file(
    SongProject project,
    SongArtifact artifact,
    String action,
  ) async {
    setState(() => _busy = true);
    try {
      final path = await ref.read(songApiProvider).download(project, artifact);
      final success = await SongDeviceFiles().perform(action, path, artifact);
      if (!mounted) return;
      _notice(
        success
            ? tr(
                action == 'save'
                    ? 'Saved to Downloads / Ovexiq.'
                    : 'Opened on your device.',
                action == 'save'
                    ? 'Downloads / Ovexiq တွင် သိမ်းပြီးပါပြီ။'
                    : 'စက်ပေါ်တွင် ဖွင့်ထားပါသည်။',
              )
            : tr(
                'Could not open or save this file. Please check device storage and a compatible media app.',
                'ဖိုင်ကို ဖွင့်ခြင်း သို့မဟုတ် သိမ်းခြင်း မအောင်မြင်ပါ။ စက်၏နေရာလွတ်နှင့် ဖိုင်ဖွင့်နိုင်သောအက်ပ်ကို စစ်ဆေးပေးပါ။',
              ),
      );
    } catch (_) {
      if (mounted) {
        _notice(
          tr(
            'Download did not complete. Your server result is still saved.',
            'ဖိုင်ဒေါင်းလုဒ် မပြီးသေးပါ။ ရလဒ်ကို ဆာဗာပေါ်တွင် သိမ်းထားဆဲဖြစ်ပါသည်။',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _status(SongProject p) => switch (p.status) {
    'completed' => tr('Files ready', 'ဖိုင်များ အဆင်သင့်ဖြစ်ပါပြီ'),
    'failed' || 'interrupted' => tr(
      'Not completed — saved outputs below. No automatic retry.',
      'မပြီးသေးပါ။ သိမ်းထားသော ရလဒ်များကို အောက်တွင် ကြည့်နိုင်ပါသည်။ အလိုအလျောက် ထပ်မလုပ်ပါ။',
    ),
    'queued' => tr('Waiting to start', 'စတင်ရန် စောင့်နေပါသည်'),
    'specifying' => tr('Writing your song', 'သီချင်းရေးနေပါသည်'),
    'generating' => tr('Creating song audio', 'သီချင်းအသံ ဖန်တီးနေပါသည်'),
    _ => tr('Preparing videos', 'ဗီဒီယိုများ ပြင်ဆင်နေပါသည်'),
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr('Songs & projects', 'သီချင်းနှင့် ဖိုင်များ')),
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          tooltip: tr('Refresh', 'ပြန်ဖွင့်ကြည့်ရန်'),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_loading || _busy) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_error!),
          ),
        TextField(
          controller: _goal,
          enabled: !_busy,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: tr(
              'Describe your original song',
              'ဖန်တီးလိုသော မူရင်းသီချင်းအကြောင်း ရေးပါ',
            ),
          ),
        ),
        DropdownButton<String>(
          value: _language,
          items: const [
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: 'my', child: Text('မြန်မာ')),
          ],
          onChanged: _busy
              ? null
              : (value) => setState(() => _language = value!),
        ),
        TextField(
          controller: _artistName,
          enabled: !_busy && _visualIds.isEmpty,
          decoration: InputDecoration(
            labelText: tr('Fictional artist name', 'ဖန်တီးထားသော အဆိုတော်အမည်'),
          ),
        ),
        Text(
          tr(
            'Original male singer · warm baritone · reusable visual identity. Consistent voice direction is not voice cloning.',
            'ကိုယ်ပိုင် အမျိုးသားအဆိုတော် · နွေးထွေးသော အသံနိမ့် · ပုံရိပ်တစ်သမတ်တည်း သုံးမည်။ အသံပုံစံကို လမ်းညွှန်ခြင်းသာဖြစ်ပြီး အသံပွားခြင်း မဟုတ်ပါ။',
          ),
        ),
        CheckboxListTile(
          value: _rightsConfirmed,
          contentPadding: EdgeInsets.zero,
          onChanged: _busy
              ? null
              : (value) => setState(() => _rightsConfirmed = value!),
          title: Text(
            tr(
              'I have permission to use these four artist images.',
              'အဆိုတော်ပုံ ၄ ပုံကို အသုံးပြုခွင့် ရှိပါသည်။',
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _busy || !_rightsConfirmed ? null : _visuals,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(
            tr(
              'Select 4 artist images (${_visualIds.length}/4 saved)',
              'အဆိုတော်ပုံ ၄ ပုံ ရွေးရန် (${_visualIds.length}/4 သိမ်းပြီး)',
            ),
          ),
        ),
        FilledButton(
          onPressed:
              _busy ||
                  _visualIds.length != 4 ||
                  !_rightsConfirmed ||
                  _projects.any((p) => p.isActive)
              ? null
              : _create,
          child: Text(
            tr('Create song + videos', 'သီချင်းနှင့် ဗီဒီယိုများ ဖန်တီးရန်'),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          tr('Saved projects', 'သိမ်းထားသော သီချင်းများ'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (final project in _projects)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title.isEmpty
                        ? tr('Original song', 'မူရင်းသီချင်း')
                        : project.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(_status(project)),
                  if (project.lyrics.isNotEmpty)
                    ExpansionTile(
                      title: Text(tr('Lyrics', 'သီချင်းစာသား')),
                      children: [
                        SelectableText(project.lyrics),
                        TextButton(
                          onPressed: () => Clipboard.setData(
                            ClipboardData(text: project.lyrics),
                          ),
                          child: Text(tr('Copy lyrics', 'စာသားကူးရန်')),
                        ),
                      ],
                    ),
                  for (final artifact in project.artifacts)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${artifact.fileName} · ${(artifact.byteSize / 1048576).toStringAsFixed(1)} MB',
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final action in ['open', 'save', 'share'])
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _file(project, artifact, action),
                                child: Text(switch (action) {
                                  'open' => tr(
                                    'Download & open',
                                    'ဒေါင်းလုဒ်၍ ဖွင့်ရန်',
                                  ),
                                  'save' => tr('Save', 'သိမ်းရန်'),
                                  _ => tr('Share', 'မျှဝေရန်'),
                                }),
                              ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
