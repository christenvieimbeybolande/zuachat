import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class ChatAudioBubble extends StatefulWidget {
  final bool isMe;
  final String url;
  final int duration;
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

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();

    _durSub = _player.onDurationChanged.listen((d) {
      setState(() => _total = d);
    });

    _posSub = _player.onPositionChanged.listen((p) {
      setState(() => _position = p);
    });

    _stateSub = _player.onPlayerStateChanged.listen((s) {
      setState(() => _playing = s == PlayerState.playing);
    });
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
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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
                IconButton(
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
                    max: (_total.inMilliseconds > 0)
                        ? _total.inMilliseconds.toDouble()
                        : widget.duration * 1000,
                    value: _position.inMilliseconds
                        .clamp(0, _total.inMilliseconds)
                        .toDouble(),
                    onChanged: (v) async {
                      await _player.seek(
                        Duration(milliseconds: v.toInt()),
                      );
                    },
                  ),
                ),
                Text(
                  '${_fmt(_position)} / ${_fmt(_total)}',
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
