import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

class ChatAudioBubble extends StatefulWidget {
  final bool isMe;
  final String url;
  final int duration;
  final String time;
  final String? avatarUrl;

  const ChatAudioBubble({
    super.key,
    required this.isMe,
    required this.url,
    required this.duration,
    required this.time,
    this.avatarUrl,
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
  bool _listened = false;

  double _speed = 1.0;

  File? _localFile;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();

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
      if (!mounted) return;
      setState(() {
        _playing = false;
        _position = _total;
        _listened = true;
      });
    });

    _prepareCache();
  }

  // ================= CACHE =================
  Future<void> _prepareCache() async {
    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${dir.path}/chat_audios');
    if (!audioDir.existsSync()) {
      audioDir.createSync(recursive: true);
    }

    final name = widget.url.split('/').last;
    final file = File('${audioDir.path}/$name');

    if (file.existsSync()) {
      _localFile = file;
      _downloaded = true;
      if (mounted) setState(() {});
    }
  }

  // ================= DOWNLOAD =================
  Future<void> _download() async {
    if (_downloading) return;

    setState(() => _downloading = true);

    try {
      final res = await http.get(Uri.parse(widget.url));
      if (res.statusCode != 200) throw Exception();

      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/chat_audios');
      if (!audioDir.existsSync()) {
        audioDir.createSync(recursive: true);
      }

      final file = File('${audioDir.path}/${widget.url.split('/').last}');
      await file.writeAsBytes(res.bodyBytes);

      _localFile = file;
      _downloaded = true;
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  // ================= PLAY / PAUSE =================
  Future<void> _togglePlay() async {
    if (!_downloaded || _localFile == null) return;

    if (_playing) {
      await _player.pause();
    } else {
      await _player.setPlaybackRate(_speed);
      await _player.play(DeviceFileSource(_localFile!.path));
    }
  }

  // ================= SPEED =================
  void _toggleSpeed() {
    setState(() {
      _speed = _speed == 1.0
          ? 1.5
          : _speed == 1.5
              ? 2.0
              : 1.0;
    });
    _player.setPlaybackRate(_speed);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final total =
        _total.inMilliseconds > 0 ? _total : Duration(seconds: widget.duration);

    final maxMs =
        total.inMilliseconds > 0 ? total.inMilliseconds.toDouble() : 1.0;

    final bubbleColor = widget.isMe
        ? Colors.red
        : _listened
            ? Colors.grey.shade200
            : Theme.of(context).cardColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!widget.isMe) _avatar(),
          _bubble(bubbleColor, maxMs, total),
          if (widget.isMe) _avatar(),
        ],
      ),
    );
  }

  Widget _avatar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: CircleAvatar(
        radius: 16,
        backgroundImage: CachedNetworkImageProvider(
          widget.avatarUrl ?? 'https://zuachat.com/assets/default-avatar.png',
        ),
      ),
    );
  }

  Widget _bubble(Color color, double maxMs, Duration total) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _downloading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      iconSize: 24,
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        !_downloaded
                            ? Icons.download
                            : _playing
                                ? Icons.pause
                                : Icons.play_arrow,
                      ),
                      onPressed: !_downloaded ? _download : _togglePlay,
                    ),
              Expanded(
                child: Slider(
                  min: 0,
                  max: maxMs,
                  value: _position.inMilliseconds
                      .clamp(0, maxMs.toInt())
                      .toDouble(),
                  onChanged: !_downloaded
                      ? null
                      : (v) => _player.seek(
                            Duration(milliseconds: v.toInt()),
                          ),
                ),
              ),
              InkWell(
                onTap: _toggleSpeed,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${_speed}x',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ⏱️ COMPTEURS EN BAS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Text(
                  _fmt(_position),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const Spacer(),
                Text(
                  _fmt(total),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),

          Align(
            alignment: Alignment.centerRight,
            child: Text(
              widget.time,
              style: const TextStyle(fontSize: 9, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
