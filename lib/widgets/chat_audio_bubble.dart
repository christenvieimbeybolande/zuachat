// lib/widgets/chat_audio_bubble.dart
import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class ChatAudioBubble extends StatefulWidget {
  final bool isMe;
  final String url;
  final int duration; // durée fournie par le serveur (en secondes) - fallback
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

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completeSub;

  @override
  void initState() {
    super.initState();

    // Listeners
    _durSub = _player.onDurationChanged.listen((d) {
      if (mounted && d.inMilliseconds > 0) {
        setState(() => _total = d);
        debugPrint('[audio] duration updated: $_total');
      }
    });

    _posSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });

    // onComplete (some versions expose onPlayerComplete)
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _position = _total; // jump to end
        });
      }
    });

    // Prepare local cache if file already downloaded
    _prepareCache();
  }

  Future<void> _prepareCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/chat_audios');
      if (!audioDir.existsSync()) audioDir.createSync(recursive: true);

      final name = widget.url.split('/').last;
      final file = File('${audioDir.path}/$name');

      if (file.existsSync()) {
        _localFile = file;
        debugPrint('[audio] local cache found: ${file.path}');
      } else {
        debugPrint('[audio] no local cache for $name');
      }
    } catch (e, st) {
      debugPrint('[audio] prepareCache error: $e\n$st');
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_playing) {
        await _player.pause();
        return;
      }

      // If we already have a local file, play that directly
      if (_localFile != null && _localFile!.existsSync()) {
        debugPrint('[audio] playing local file ${_localFile!.path}');
        // play Device file
        await _player.play(DeviceFileSource(_localFile!.path));
        return;
      }

      // Try streaming first
      debugPrint('[audio] try streaming: ${widget.url}');
      try {
        // play() will stream and start playback immediately if possible
        await _player.play(UrlSource(widget.url));
        return;
      } catch (e) {
        // streaming failed -> fallback to download
        debugPrint('[audio] streaming failed: $e, fallback to download');
      }

      // fallback: download and play
      await _downloadAndPlay();
    } catch (e, st) {
      debugPrint('[audio] toggle error: $e\n$st');
    }
  }

  Future<void> _downloadAndPlay() async {
    if (_downloading) return;
    setState(() => _downloading = true);

    try {
      debugPrint('[audio] downloading ${widget.url}');
      final uri = Uri.parse(widget.url);
      final res = await http.get(uri);
      debugPrint('[audio] http GET status: ${res.statusCode}');
      debugPrint('[audio] response headers: ${res.headers}');

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/chat_audios');
      if (!audioDir.existsSync()) audioDir.createSync(recursive: true);

      final name = widget.url.split('/').last;
      final file = File('${audioDir.path}/$name');

      await file.writeAsBytes(res.bodyBytes);
      _localFile = file;
      debugPrint('[audio] written to ${file.path}');

      // Play local file
      await _player.play(DeviceFileSource(file.path));
    } catch (e, st) {
      debugPrint('[audio] downloadAndPlay error: $e\n$st');
      // si erreur, essaye encore de streamer juste pour être sûr
      try {
        debugPrint('[audio] dernière tentative: streamer');
        await _player.play(UrlSource(widget.url));
      } catch (e2) {
        debugPrint('[audio] dernier échec streaming: $e2');
        rethrow;
      }
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
    final serverDuration = Duration(seconds: widget.duration); // fallback
    final effectiveTotal = _total.inMilliseconds > 0 ? _total : serverDuration;
    final maxMs = effectiveTotal.inMilliseconds > 0 ? effectiveTotal.inMilliseconds : 1;

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.fromLTRB(widget.isMe ? 40 : 8, 4, widget.isMe ? 8 : 40, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isMe ? Colors.red : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _downloading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        icon: Icon(_playing ? Icons.pause : Icons.play_arrow, color: widget.isMe ? Colors.white : Colors.black),
                        onPressed: _toggle,
                      ),
                SizedBox(
                  width: 140,
                  child: Slider(
                    min: 0,
                    max: maxMs.toDouble(),
                    value: _position.inMilliseconds.clamp(0, maxMs).toDouble(),
                    onChanged: (v) async {
                      final pos = Duration(milliseconds: v.toInt());
                      try {
                        await _player.seek(pos);
                        // update UI immediately
                        setState(() => _position = pos);
                      } catch (e) {
                        debugPrint('[audio] seek error: $e');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_fmt(_position)} / ${_fmt(effectiveTotal)}',
                  style: TextStyle(fontSize: 10, color: widget.isMe ? Colors.white70 : Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(widget.time, style: TextStyle(fontSize: 10, color: widget.isMe ? Colors.white70 : Colors.black45)),
          ],
        ),
      ),
    );
  }
}
