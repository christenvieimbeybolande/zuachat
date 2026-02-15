import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class ChatAudioFileBubble extends StatefulWidget {
  final String url;
  final String fileName;
  final int? fileSize;
  final bool isMe;
  final String time;
  final Color primaryColor;

  const ChatAudioFileBubble({
    super.key,
    required this.url,
    required this.fileName,
    required this.isMe,
    required this.time,
    required this.primaryColor,
    this.fileSize,
  });

  @override
  State<ChatAudioFileBubble> createState() => _ChatAudioFileBubbleState();
}

class _ChatAudioFileBubbleState extends State<ChatAudioFileBubble> {
  final AudioPlayer _player = AudioPlayer();
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _loading = true;
  bool _downloading = false;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _player.setUrl(widget.url);
    _duration = _player.duration ?? Duration.zero;

    _player.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });

    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });

    final dir = await getApplicationDocumentsDirectory();
    final savePath = '${dir.path}/${widget.fileName}';

    await Dio().download(
      widget.url,
      savePath,
      onReceiveProgress: (r, t) {
        if (t > 0) {
          setState(() => _downloadProgress = r / t);
        }
      },
    );

    setState(() => _downloading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Audio téléchargé : ${widget.fileName}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isMe ? widget.primaryColor : Theme.of(context).cardColor;
    final txt = widget.isMe ? Colors.white : null;

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              widget.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: txt, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // ▶️ CONTROLS
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _player.playing ? Icons.pause : Icons.play_arrow,
                    color: txt,
                  ),
                  onPressed: _loading
                      ? null
                      : () {
                          _player.playing
                              ? _player.pause()
                              : _player.play();
                        },
                ),
                Text(
                  '${_fmt(_position)} / ${_fmt(_duration)}',
                  style: TextStyle(fontSize: 12, color: txt),
                ),
                const SizedBox(width: 12),

                // ⬇️ DOWNLOAD
                _downloading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          value: _downloadProgress,
                          strokeWidth: 2,
                          color: txt,
                        ),
                      )
                    : IconButton(
                        icon: Icon(Icons.download, color: txt),
                        onPressed: _download,
                      ),
              ],
            ),

            Align(
              alignment: Alignment.centerRight,
              child: Text(
                widget.time,
                style: TextStyle(fontSize: 9, color: txt?.withOpacity(0.8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
