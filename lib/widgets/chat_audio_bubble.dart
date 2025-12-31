// lib/widgets/chat_audio_bubble.dart
import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class ChatAudioBubble extends StatefulWidget {
  final bool isMe;
  final String url; // URL audio ABSOLUE et CORRECTE
  final int duration; // durée serveur (secondes) – fallback
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

    _prepareCache();
  }

  // ============================================================
  // CACHE
  // ============================================================
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
      debugPrint('[audio] cache OK: ${file.path}');
      if (mounted) setState(() {});
    } else {
      debugPrint('[audio] pas téléchargé: $name');
    }
  }

  // ============================================================
  // DOWNLOAD
  // ============================================================
  Future<void> _download() async {
    if (_downloading) return;

    setState(() => _downloading = true);

    try {
      debugPrint('[audio] téléchargement ${widget.url}');
      final res = await http.get(Uri.parse(widget.url));

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/chat_audios');
      if (!audioDir.existsSync()) {
        audioDir.createSync(recursive: true);
      }

      final name = widget.url.split('/').last;
      final file = File('${audioDir.path}/$name');

      await file.writeAsBytes(res.bodyBytes);

      _localFile = file;
      _downloaded = true;

      debugPrint('[audio] téléchargé OK: ${file.path}');
    } catch (e, st) {
      debugPrint('[audio] ERREUR download: $e\n$st');
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
      await _player.play(DeviceFileSource(_localFile!.path));
    }
  }

  // ============================================================
  // FORMAT
  // ============================================================
  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final fallbackTotal = Duration(seconds: widget.duration);
    final effectiveTotal = _total.inMilliseconds > 0 ? _total : fallbackTotal;

    final maxMs =
        effectiveTotal.inMilliseconds > 0 ? effectiveTotal.inMilliseconds : 1;

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
                // ===== ICONE INTELLIGENTE =====
                if (_downloading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (!_downloaded)
                  IconButton(
                    icon: Icon(
                      Icons.download,
                      color: widget.isMe ? Colors.white : Colors.black,
                    ),
                    onPressed: _download,
                  )
                else
                  IconButton(
                    icon: Icon(
                      _playing ? Icons.pause : Icons.play_arrow,
                      color: widget.isMe ? Colors.white : Colors.black,
                    ),
                    onPressed: _togglePlay,
                  ),

                // ===== SLIDER =====
                SizedBox(
                  width: 140,
                  child: Slider(
                    min: 0,
                    max: maxMs.toDouble(),
                    value: _position.inMilliseconds.clamp(0, maxMs).toDouble(),
                    onChanged: !_downloaded
                        ? null
                        : (v) async {
                            final pos = Duration(milliseconds: v.toInt());
                            await _player.seek(pos);
                            setState(() => _position = pos);
                          },
                  ),
                ),

                const SizedBox(width: 6),
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

  // ============================================================
  // DISPOSE
  // ============================================================
  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }
}
