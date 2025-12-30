import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class ChatAudioBubble extends StatefulWidget {
  final bool isMe;
  final String url;
  final int duration; // 🔥 durée serveur (secondes)
  final String time;

  const ChatAudioBubble({
    super.key,
    required this.isMe,
    required this.url,
    required this.duration,
    required this.time,
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

  File? _localFile;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _prepareCache();

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
  }

  Future<void> _prepareCache() async {
    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${dir.path}/chat_audios');
    if (!audioDir.existsSync()) audioDir.createSync(recursive: true);

    final name = widget.url.split('/').last;
    final file = File('${audioDir.path}/$name');

    if (file.existsSync()) {
      _localFile = file;
    }
  }

  @override
  void dispose() {
    _player.stop();
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }

    if (_localFile != null && _localFile!.existsSync()) {
      await _player.setSourceDeviceFile(_localFile!.path);
      await _player.resume();
      return;
    }

    await _downloadAndPlay();
  }

  Future<void> _downloadAndPlay() async {
    if (_downloading) return;
    setState(() => _downloading = true);

    try {
      final res = await http.get(Uri.parse(widget.url));
      if (res.statusCode != 200) throw Exception();

      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/chat_audios');
      if (!audioDir.existsSync()) audioDir.createSync(recursive: true);

      final name = widget.url.split('/').last;
      final file = File('${audioDir.path}/$name');
      await file.writeAsBytes(res.bodyBytes);

      _localFile = file;

      await _player.setSourceDeviceFile(file.path);
      await _player.resume();
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final serverDuration = Duration(seconds: widget.duration); // 🔥 fallback

    final effectiveTotal = _total.inMilliseconds > 0 ? _total : serverDuration;

    final maxMs = effectiveTotal.inMilliseconds;

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.fromLTRB(
          widget.isMe ? 40 : 8,
          4,
          widget.isMe ? 8 : 40,
          4,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isMe ? Colors.red : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment:
              widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _downloading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: Icon(
                          _playing ? Icons.pause : Icons.play_arrow,
                          color: widget.isMe ? Colors.white : Colors.black,
                        ),
                        onPressed: _toggle,
                      ),
                SizedBox(
                  width: 120,
                  child: Slider(
                    min: 0,
                    max: maxMs.toDouble(),
                    value: _position.inMilliseconds.clamp(0, maxMs).toDouble(),
                    onChanged: (v) {
                      _player.seek(Duration(milliseconds: v.toInt()));
                    },
                  ),
                ),
                Text(
                  '${_fmt(_position)} / ${_fmt(effectiveTotal)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.isMe ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              widget.time,
              style: TextStyle(
                fontSize: 10,
                color: widget.isMe ? Colors.white70 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
