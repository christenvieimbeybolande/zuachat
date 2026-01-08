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
  final bool seen; // ✅ AJOUT
  final Widget? replyPreview;

  const ChatAudioBubble({
    super.key,
    required this.isMe,
    required this.url,
    required this.duration,
    required this.time,
    required this.seen, // ✅ AJOUT
    this.avatarUrl,
    this.replyPreview,
  });

  @override
  State<ChatAudioBubble> createState() => _ChatAudioBubbleState();
}

class _ChatAudioBubbleState extends State<ChatAudioBubble>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();

  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

  bool _playing = false;
  bool _downloading = false;
  bool _downloaded = false;

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

    _prepareCache();
  }

  // ================= CACHE =================
  Future<void> _prepareCache() async {
    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${dir.path}/chat_audios');
    if (!audioDir.existsSync()) audioDir.createSync(recursive: true);

    final file = File('${audioDir.path}/${widget.url.split('/').last}');
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
      if (res.statusCode != 200) return;

      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/chat_audios');
      if (!audioDir.existsSync()) audioDir.createSync(recursive: true);

      final file = File('${audioDir.path}/${widget.url.split('/').last}');
      await file.writeAsBytes(res.bodyBytes);

      _localFile = file;
      _downloaded = true;
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  // ================= PLAY =================
  Future<void> _togglePlay() async {
    if (!_downloaded || _localFile == null) return;

    if (_playing) {
      await _player.pause();
    } else {
      await _player.setPlaybackRate(_speed);
      await _player.play(DeviceFileSource(_localFile!.path));
    }
  }

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

    final isMe = widget.isMe;
    final fg = isMe ? Colors.white : Colors.black54;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) _avatar(),
          Container(
            constraints: const BoxConstraints(maxWidth: 230),
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            decoration: BoxDecoration(
              color: isMe ? Colors.red : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔁 PREVIEW DU MESSAGE RÉPONDU
                if (widget.replyPreview != null) widget.replyPreview!,

                // 🕒 HEURE EN HAUT
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.time,
                      style: TextStyle(fontSize: 9, color: fg),
                    ),
                    const SizedBox(width: 4),
                    _seenIcon(), // ✅ AJOUT
                  ],
                ),

                Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _downloading
                          ? SizedBox(
                              key: const ValueKey('load'),
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: fg,
                              ),
                            )
                          : IconButton(
                              key: ValueKey(_playing),
                              iconSize: 22,
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                !_downloaded
                                    ? Icons.download
                                    : _playing
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                color: fg,
                              ),
                              onPressed: !_downloaded ? _download : _togglePlay,
                            ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5),
                          activeTrackColor: fg,
                          inactiveTrackColor: fg.withOpacity(.3),
                          thumbColor: fg,
                        ),
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
                    ),
                    GestureDetector(
                      onTap: _toggleSpeed,
                      child: Text(
                        '${_speed}x',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: fg),
                      ),
                    ),
                  ],
                ),

                // ⏱️ DURÉES
                Row(
                  children: [
                    Text(_fmt(_position),
                        style: TextStyle(fontSize: 9, color: fg)),
                    const Spacer(),
                    Text(_fmt(total), style: TextStyle(fontSize: 9, color: fg)),
                  ],
                ),
              ],
            ),
          ),
          if (isMe) _avatar(),
        ],
      ),
    );
  }

  Widget _seenIcon() {
    if (!widget.isMe) return const SizedBox.shrink();

    return Icon(
      Icons.done_all,
      size: 14,
      color: widget.seen
          ? Colors.lightBlueAccent // ✓✓ vu
          : Colors.white70, // ✓✓ envoyé
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

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
