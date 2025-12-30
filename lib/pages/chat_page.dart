import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';

import '../api/chat_messages.dart';
import '../api/send_chat_message.dart'; // ✅ API UNIQUE
import '../api/delete_chat_message.dart';
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

  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  // ================= AUDIO =================
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  Timer? _recordTimer;
  Duration _recordDuration = Duration.zero;
  bool _recording = false;

  bool _loading = true;
  bool _sending = false;
  bool _error = false;

  List<Map<String, dynamic>> _messages = [];
  DateTime? _lastLoadAt;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
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

  // ============================================================
  // 🔄 LOAD MESSAGES
  // ============================================================
  Future<void> _load({bool initial = false, bool scrollToEnd = true}) async {
    final now = DateTime.now();

    if (!initial &&
        _lastLoadAt != null &&
        now.difference(_lastLoadAt!) < const Duration(seconds: 2)) {
      return;
    }

    _lastLoadAt = now;

    if (initial) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }

    try {
      final raw = await apiFetchChatMessages(widget.contactId);
      if (!mounted) return;

      setState(() {
        _messages = List<Map<String, dynamic>>.from(raw);
        _loading = false;
      });

      if (scrollToEnd) {
        await Future.delayed(const Duration(milliseconds: 80));
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  bool _isMe(int senderId) => senderId != widget.contactId;

  // ============================================================
  // ✉️ SEND TEXT
  // ============================================================
  Future<void> _sendText() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      _msgCtrl.clear();

      await apiSendMessage(
        receiverId: widget.contactId,
        message: text,
      );

      await _load(scrollToEnd: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ============================================================
  // 🎙️ AUDIO START
  // ============================================================
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

  // ============================================================
  // 🎙️ AUDIO STOP & SEND
  // ============================================================
  Future<void> _stopRecordingAndSend() async {
    _recordTimer?.cancel();

    final path = await _recorder.stop();
    if (path == null) return;

    final file = File(path);
    if (!file.existsSync() || _recordDuration.inSeconds == 0) {
      setState(() => _recording = false);
      return;
    }

    await apiSendMessage(
      receiverId: widget.contactId,
      audioFile: file,
      duration: _recordDuration.inSeconds,
    );

    setState(() {
      _recording = false;
      _recordDuration = Duration.zero;
    });

    _load(scrollToEnd: true);
  }

  // ============================================================
  // 🧱 MESSAGE BUBBLE
  // ============================================================
  Widget _bubble(Map m) {
    final isMe = _isMe(int.parse("${m['sender_id']}"));
    final deleted = m["deleted_by"] != null;
    final type = m['type'] ?? 'text';

    if (type == 'audio' && !deleted) {
      return _audioBubble(m, isMe);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.fromLTRB(isMe ? 40 : 8, 4, isMe ? 8 : 40, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? primary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          deleted ? "Message supprimé" : (m["message"] ?? ""),
          style: TextStyle(color: isMe ? Colors.white : null),
        ),
      ),
    );
  }

  Widget _audioBubble(Map m, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.fromLTRB(isMe ? 40 : 8, 4, isMe ? 8 : 40, 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? primary : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              onPressed: () =>
                  _player.play(UrlSource(m['audio_path'])),
            ),
            Text("${m['audio_duration']}s",
                style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 📝 INPUT
  // ============================================================
  Widget _inputField() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: "Votre message…",
                ),
              ),
            ),
            GestureDetector(
              onTap: _sendText,
              onLongPress: _startRecording,
              onLongPressEnd: (_) {
                if (_recording) _stopRecordingAndSend();
              },
              child: CircleAvatar(
                backgroundColor: primary,
                child: Icon(
                  _recording ? Icons.mic : Icons.send,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================
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
                : _error
                    ? Center(
                        child: ElevatedButton(
                          onPressed: () => _load(initial: true),
                          child: const Text("Réessayer"),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(10),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _bubble(_messages[i]),
                      ),
          ),
          _inputField(),
        ],
      ),
    );
  }
}
