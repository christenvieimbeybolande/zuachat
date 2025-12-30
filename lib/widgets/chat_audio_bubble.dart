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
  Duration _pos = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onPositionChanged.listen((p) {
      setState(() => _pos = p);
    });
    _player.onPlayerComplete.listen((_) {
      setState(() {
        _playing = false;
        _pos = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final bg = widget.isMe ? Colors.red : Theme.of(context).cardColor;

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                _playing ? Icons.pause : Icons.play_arrow,
                color: widget.isMe ? Colors.white : Colors.black,
              ),
              onPressed: () async {
                if (_playing) {
                  await _player.pause();
                } else {
                  await _player.play(
                    UrlSource(
                        'https://zuachat.com/uploads/audios/${widget.url}'),
                  );
                }
                setState(() => _playing = !_playing);
              },
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_fmt(_pos)} / ${_fmt(Duration(seconds: widget.duration))}',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isMe ? Colors.white70 : Colors.black54,
                  ),
                ),
                Text(
                  widget.time,
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
