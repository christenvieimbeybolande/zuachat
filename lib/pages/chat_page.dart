import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

import '../api/chat_messages.dart';
import '../api/send_chat_message.dart';
import '../api/delete_chat_message.dart';
import '../core/env.dart';
import '../pages/user_profile.dart';

class ChatPage extends StatefulWidget {
  final int contactId;
  final String contactName;
  final String contactPhoto;
  final bool badgeVerified;

  const ChatPage({
    super.key,
    required this.contactId,
    required this.contactName,
    required this.contactPhoto,
    required this.badgeVerified,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const Color primary = Color(0xFFFF0000);

  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  Timer? _recordTimer;
  Duration _recordDuration = Duration.zero;
  bool _recording = false;

  Duration _audioPosition = Duration.zero;
  Duration _audioTotal = Duration.zero;
  int? _playingMessageId;

  bool _loading = true;
  bool _sending = false;
  bool _error = false;

  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _load(initial: true);

    _player.onPositionChanged.listen((p) {
      setState(() => _audioPosition = p);
    });

    _player.onDurationChanged.listen((d) {
      setState(() => _audioTotal = d);
    });

    _player.onPlayerComplete.listen((_) {
      setState(() {
        _playingMessageId = null;
        _audioPosition = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  // ================= LOAD =================
  Future<void> _load({bool initial = false}) async {
    try {
      final raw = await apiFetchChatMessages(widget.contactId);
      if (!mounted) return;

      setState(() {
        _messages = List<Map<String, dynamic>>.from(raw);
        _loading = false;
      });

      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    } catch (_) {
      setState(() => _error = true);
    }
  }

  bool _isMe(int senderId) => senderId != widget.contactId;

  // ================= SEND TEXT =================
  Future<void> _sendText() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _msgCtrl.clear();

    await apiSendMessage(
      receiverId: widget.contactId,
      message: text,
    );

    _load();
  }

  // ================= AUDIO =================
  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 40);
    }

    _recordDuration = Duration.zero;
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordDuration += const Duration(seconds: 1));
    });

    setState(() => _recording = true);
  }

  Future<void> _stopRecordingAndSend() async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    if (path == null) return;

    final file = File(path);
    if (!file.existsSync()) return;

    await apiSendMessage(
      receiverId: widget.contactId,
      audioFile: file,
      duration: _recordDuration.inSeconds,
    );

    setState(() {
      _recording = false;
      _recordDuration = Duration.zero;
    });

    _load();
  }

  // ================= BUBBLES =================
  Widget _audioBubble(Map m, bool isMe) {
    final id = m['id'];
    final url = "${Env.apiBase}${m['audio_path']}";

    final playing = _playingMessageId == id;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? primary : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(playing ? Icons.pause : Icons.play_arrow,
                  color: Colors.white),
              onPressed: () async {
                if (playing) {
                  await _player.pause();
                  setState(() => _playingMessageId = null);
                } else {
                  await _player.play(UrlSource(url));
                  setState(() => _playingMessageId = id);
                }
              },
            ),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                value: _audioTotal.inMilliseconds == 0
                    ? 0
                    : _audioPosition.inMilliseconds /
                        _audioTotal.inMilliseconds,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              m['time'] ?? '',
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            )
          ],
        ),
      ),
    );
  }

  Widget _textBubble(Map m) {
    final isMe = _isMe(int.parse("${m['sender_id']}"));

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? primary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              m['message'] ?? '',
              style: TextStyle(color: isMe ? Colors.white : null),
            ),
            const SizedBox(height: 4),
            Text(
              m['time'] ?? '',
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            )
          ],
        ),
      ),
    );
  }

  // ================= INPUT =================
  Widget _inputField() {
    final hasText = _msgCtrl.text.trim().isNotEmpty;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                onChanged: (_) => setState(() {}),
                minLines: 1,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: "Message",
                  border: InputBorder.none,
                ),
              ),
            ),
            GestureDetector(
              onTap: hasText ? _sendText : null,
              onLongPress: hasText ? null : _startRecording,
              onLongPressEnd: (_) {
                if (_recording) _stopRecordingAndSend();
              },
              child: CircleAvatar(
                backgroundColor: primary,
                child: Icon(
                  hasText ? Icons.send : Icons.mic,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        title: Text(widget.contactName),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollCtrl,
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      if (m['type'] == 'audio') {
                        return _audioBubble(
                            m, _isMe(int.parse("${m['sender_id']}")));
                      }
                      return _textBubble(m);
                    },
                  ),
          ),
          _inputField(),
        ],
      ),
    );
  }
}
