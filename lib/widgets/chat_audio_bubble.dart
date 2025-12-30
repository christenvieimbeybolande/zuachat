import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

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

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();

    _duration = Duration(seconds: widget.duration);

    _player.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _player.onPositionChanged.listen((pos) {
      setState(() {
        _position = pos;
      });
    });

    _player.onDurationChanged.listen((dur) {
      setState(() {
        _duration = dur;
      });
    });

    _player.onPlayerComplete.listen((_) {
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isMe ? Colors.red : Theme.of(context).cardColor;
    final fg = widget.isMe ? Colors.white : Colors.black87;

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.fromLTRB(
          widget.isMe ? 40 : 8,
          4,
          widget.isMe ? 8 : 40,
          4,
        ),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bg,
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
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: fg,
                  ),
                  onPressed: () async {
                    if (_isPlaying) {
                      await _player.pause();
                    } else {
                      await _player.play(
                        UrlSource(widget.url),
                      );
                    }
                  },
                ),
                SizedBox(
                  width: 140,
                  child: Slider(
                    min: 0,
                    max: _duration.inSeconds
                        .toDouble()
                        .clamp(1, double.infinity),
                    value: _position.inSeconds
                        .toDouble()
                        .clamp(0, _duration.inSeconds.toDouble()),
                    onChanged: (v) async {
                      await _player.seek(Duration(seconds: v.toInt()));
                    },
                    activeColor: fg,
                    inactiveColor: fg.withOpacity(.3),
                  ),
                ),
                Text(
                  '${_fmt(_position)} / ${_fmt(_duration)}',
                  style: TextStyle(fontSize: 11, color: fg),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              widget.time,
              style: TextStyle(
                fontSize: 10,
                color: fg.withOpacity(.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
