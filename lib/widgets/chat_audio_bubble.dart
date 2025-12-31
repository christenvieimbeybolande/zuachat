// lib/widgets/chat_audio_bubble.dart
import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class ChatAudioBubble extends StatefulWidget {
  final bool isMe;

  /// URL distante (audio reçu)
  final String? url;

  /// Chemin local (audio envoyé par moi)
  final String? localPath;

  final int duration; // secondes
  final String time;

  final String myAvatar;
  final String contactAvatar;

  const ChatAudioBubble({
    super.key,
    required this.isMe,
    this.url,
    this.localPath,
    required this.duration,
    required this.time,
    required this.myAvatar,
    required this.contactAvatar,
  });

  @override
  State<ChatAudioBubble> createState() => _ChatAudioBubbleState();
}

class _ChatAudioBubbleState extends State<ChatAudioBubble> {
  final AudioPlayer _player = AudioPlayer();

  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

  bool _playing = false;
  bool _downloading = false;
  bool _downloaded = false;

  File? _localFile;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;

  // ============================================================
  // INIT
  // ============================================================
  @override
  void initState() {
    super.initState();

    // fallback durée serveur
    _total = Duration(seconds: widget.duration);

    _durSub = _player.onDurationChanged.listen((d) {
      if (mounted && d.inMilliseconds > 0) {
        setState(() => _total = d);
      }
    });

    _posSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _position = _total;
        });
      }
    });

    _prepareAudio();
  }

  // ============================================================
  // PREPARE AUDIO (LOCAL > CACHE > REMOTE)
  // ============================================================
  Future<void> _prepareAudio() async {
    // 1️⃣ AUDIO LOCAL (envoyé par moi)
    if (widget.localPath != null && widget.localPath!.isNotEmpty) {
      final file = File(widget.localPath!);
      if (file.existsSync()) {
        _localFile = file;
        _downloaded = true;
        if (mounted) setState(() {});
        return;
      }
    }

    // 2️⃣ AUDIO REÇU → cache
    if (widget.url == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${dir.path}/chat_audios');
    if (!audioDir.existsSync()) {
      audioDir.createSync(recursive: true);
    }

    final name = widget.url!.split('/').last;
    final file = File('${audioDir.path}/$name');

    if (file.existsSync()) {
      _localFile = file;
      _downloaded = true;
      if (mounted) setState(() {});
    }
  }

  // ============================================================
  // DOWNLOAD (SEULEMENT POUR AUDIO REÇU)
  // ============================================================
  Future<void> _download() async {
    if (_downloading) return;
    if (widget.isMe) return;
    if (widget.url == null) return;

    setState(() => _downloading = true);

    try {
      final res = await http.get(Uri.parse(widget.url!));
      if (res.statusCode != 200) return;

      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/chat_audios');
      if (!audioDir.existsSync()) {
        audioDir.createSync(recursive: true);
      }

      final name = widget.url!.split('/').last;
      final file = File('${audioDir.path}/$name');
      await file.writeAsBytes(res.bodyBytes);

      _localFile = file;
      _downloaded = true;
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  // ============================================================
  // PLAY / PAUSE
  // ============================================================
  Future<void> _togglePlay() async {
    if (!_downloaded || _localFile == null) return;

    if (_playing) {
      await _player.pause();
    } else {
      await _player.stop(); // 🔥 évite audio multiple
      await _player.play(DeviceFileSource(_localFile!.path));
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================
  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  ImageProvider _avatar(String url) {
    if (url.isEmpty) {
      return const AssetImage('assets/default-avatar.png');
    }
    return NetworkImage(url);
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final maxMs = _total.inMilliseconds > 0 ? _total.inMilliseconds : 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment:
            widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!widget.isMe)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: CircleAvatar(
                radius: 16,
                backgroundImage: _avatar(widget.contactAvatar),
              ),
            ),
          Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isMe
                  ? const Color(0xFFDCF8C6)
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmt(_total),
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (_downloading)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (!_downloaded && !widget.isMe)
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.download, size: 22),
                        onPressed: _download,
                      )
                    else
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          _playing ? Icons.pause : Icons.play_arrow,
                          size: 22,
                        ),
                        onPressed: _togglePlay,
                      ),
                    Expanded(
                      child: Slider(
                        min: 0,
                        max: maxMs.toDouble(),
                        value:
                            _position.inMilliseconds.clamp(0, maxMs).toDouble(),
                        onChanged: !_downloaded
                            ? null
                            : (v) async {
                                final pos = Duration(milliseconds: v.toInt());
                                await _player.seek(pos);
                                setState(() => _position = pos);
                              },
                      ),
                    ),
                    Text(
                      widget.time,
                      style:
                          const TextStyle(fontSize: 10, color: Colors.black45),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.isMe)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: CircleAvatar(
                radius: 16,
                backgroundImage: _avatar(widget.myAvatar),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================
  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
