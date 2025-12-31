import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:vibration/vibration.dart';
import '../api/client.dart';

import '../api/chat_messages.dart';
import '../api/send_chat_message.dart';
import '../api/send_audio_message.dart';
import '../api/delete_chat_message.dart';

import '../widgets/chat_audio_bubble.dart';
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
  static const primary = Color(0xFFFF0000);
  late final int myUserId;

  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  // =========================
  // 🎙️ AUDIO STATE
  // =========================
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  bool _isLocked = false;
  bool _isPaused = false;

  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;

  String? _recordPath;

  bool _loading = true;
  bool _sending = false;
  bool _error = false;

  List<Map<String, dynamic>> _messages = [];
  DateTime? _lastLoadAt;

  @override
  void initState() {
    super.initState();

    myUserId = ApiClient.userId; // ✅ ID réel de l'utilisateur connecté

    _msgCtrl.addListener(() {
      setState(() {});
    });

    _load(initial: true);
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _recorder.dispose(); // ✅ OBLIGATOIRE avec AudioRecorder
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // 🔄 Charger messages
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
      final msgs = List<Map<String, dynamic>>.from(raw);

      if (!mounted) return;

      setState(() {
        _messages = msgs;
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

  // ============================================================
  // ✉️ Envoyer message
  // ============================================================
  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      await apiSendChatMessage(
        receiverId: widget.contactId,
        message: text,
      );

      _msgCtrl.clear();
      await _load(scrollToEnd: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ============================================================
  // 🎙️ AUDIO - START RECORDING
  // ============================================================
  Future<void> _startRecording() async {
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) return;

    final dir = await getTemporaryDirectory();
    _recordPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _recordPath!,
    );

    _recordDuration = Duration.zero;
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _recordDuration += const Duration(seconds: 1);
      });
    });

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 40);
    }

    setState(() {
      _isRecording = true;
      _isPaused = false;
    });
  }

  // ============================================================
  // ⏹️ AUDIO - STOP / SEND
  // ============================================================
  Future<void> _stopRecording({bool send = true}) async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    if (path != null) {
      _recordPath = path;
    }

    if (send && _recordPath != null) {
      await apiSendAudioMessage(
        receiverId: widget.contactId,
        filePath: _recordPath!,
        duration: _recordDuration.inSeconds,
      );
      _messages.add({
        "type": "audio",
        "sender_id": myUserId,

        "local_path": _recordPath, // 🔥 OBLIGATOIRE
        "audio_duration": _recordDuration.inSeconds,
        "time": "Maintenant",
      });
      setState(() {});

      await _load(scrollToEnd: true);
    }

    setState(() {
      _isRecording = false;
      _isLocked = false;
      _isPaused = false;
      _recordDuration = Duration.zero;
    });
  }

  // ============================================================
  // ❌ AUDIO - CANCEL
  // ============================================================
  void _cancelRecording() async {
    _recordTimer?.cancel();
    await _recorder.stop();
    _recordPath = null;

    setState(() {
      _isRecording = false;
      _isLocked = false;
      _isPaused = false;
    });
  }

  bool _isMe(int senderId) => senderId != widget.contactId;

  // ============================================================
  // 📌 Options message
  // ============================================================
  void _openOptions({
    required Map msg,
    required bool isMe,
    required bool isAudio,
  }) {
    if (msg["deleted_by"] != null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            // 📝 COPIER (UNIQUEMENT TEXTE)
            if (!isAudio)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text("Copier"),
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: msg["message"] ?? ""),
                  );
                  Navigator.pop(context);
                },
              ),

            // 🗑 SUPPRIMER POUR MOI
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text("Supprimer pour moi"),
              onTap: () async {
                Navigator.pop(context);
                await apiDeleteMessage(msg["id"], forAll: false);
                _load();
              },
            ),

            // 🗑 SUPPRIMER POUR TOUT LE MONDE (SEULEMENT SI MOI)
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_forever),
                title: const Text("Supprimer pour tout le monde"),
                onTap: () async {
                  Navigator.pop(context);
                  await apiDeleteMessage(msg["id"], forAll: true);
                  _load();
                },
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 💬 Bulle message (dark / light)
  // ============================================================
  Widget _bubble(Map m) {
    final isMe = _isMe(int.parse("${m['sender_id']}"));
    final deleted = m["deleted_by"] != null;
    if (deleted) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            "Message supprimé",
            style: TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    // 🔊 MESSAGE AUDIO
    if (m['type'] == 'audio' && !deleted) {
      final isMe = _isMe(int.parse("${m['sender_id']}"));

      // 🌐 URL distante (audio reçu)
      String? audioUrl;
      if (!isMe && m['audio_path'] != null) {
        String rawPath = m['audio_path'].toString().trim();

        rawPath = rawPath
            .replaceAll(RegExp(r'(?<!:)//'), '/')
            .replaceAll('audios/audios', 'audios')
            .replaceAll('uploads/uploads', 'uploads');

        if (!rawPath.startsWith('uploads/')) {
          rawPath = 'uploads/$rawPath';
        }

        audioUrl = rawPath.startsWith('http')
            ? rawPath
            : 'https://zuachat.com/$rawPath';
      }

      // 📁 chemin local (audio envoyé par moi)
      final String? localPath = isMe ? m['local_path'] as String? : null;

      return GestureDetector(
        onLongPress: () => _openOptions(
          msg: m,
          isMe: isMe,
          isAudio: true,
        ),
        child: ChatAudioBubble(
          isMe: isMe,
          url: audioUrl, // 🔥 seulement si reçu
          localPath: localPath, // 🔥 seulement si moi
          duration: int.tryParse('${m['audio_duration']}') ?? 0,
          time: m['time'] ?? '',
          myAvatar: "https://zuachat.com/uploads/avatars/me.jpg",
          contactAvatar: widget.contactPhoto,
        ),
      );
    }

    // 📝 MESSAGE TEXTE
    final text = deleted ? "Message supprimé" : (m["message"] ?? "");
    final time = m["time"] ?? "";
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onLongPress: deleted
          ? null
          : () => _openOptions(
                msg: m,
                isMe: isMe,
                isAudio: false, // 📝
              ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.fromLTRB(
            isMe ? 40 : 8,
            4,
            isMe ? 8 : 40,
            4,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: deleted
                ? Colors.grey
                : isMe
                    ? primary
                    : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: deleted
                      ? Colors.white
                      : isMe
                          ? Colors.white
                          : Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  fontSize: 10,
                  color: isMe
                      ? Colors.white70
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 🖼️ Header
  // ============================================================
  Widget _buildHeader() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfilePage(userId: widget.contactId),
          ),
        );
      },
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: widget.contactPhoto.isNotEmpty
                ? NetworkImage(widget.contactPhoto)
                : const AssetImage("assets/default-avatar.png")
                    as ImageProvider,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.contactName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (widget.badgeVerified)
            const Icon(Icons.verified, color: Colors.white, size: 18),
        ],
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: primary,
        titleSpacing: 0,
        title: _buildHeader(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _load(scrollToEnd: false),
          ),
        ],
      ),
      body: Column(
        children: [
          _recordingOverlay(),
          Expanded(
            child: Builder(
              builder: (_) {
                if (_loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_error) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () => _load(initial: true),
                      child: const Text("Réessayer"),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(10),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) => _bubble(_messages[i]),
                );
              },
            ),
          ),
          _inputField(),
        ],
      ),
    );
  }

  // ============================================================
  // 🎙️ OVERLAY RECORDING
  // ============================================================
  Widget _recordingOverlay() {
    if (!_isRecording) return const SizedBox.shrink();

    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _cancelRecording,
          ),
          Text(
            '${_recordDuration.inMinutes}:${(_recordDuration.inSeconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(color: Colors.white),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _isPaused ? Icons.play_arrow : Icons.pause,
              color: Colors.white,
            ),
            onPressed: () async {
              if (!_isRecording) return;

              if (_isPaused) {
                await _recorder.resume();
              } else {
                await _recorder.pause();
              }

              setState(() => _isPaused = !_isPaused);
            },
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.green),
            onPressed: () => _stopRecording(send: true),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 📝 Input
  // ============================================================
  Widget _inputField() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        color: Theme.of(context).cardColor,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Votre message...",
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: primary,
              child: GestureDetector(
                onTap: _msgCtrl.text.trim().isNotEmpty
                    ? (_sending ? null : _send)
                    : null,
                onLongPress:
                    _msgCtrl.text.trim().isEmpty ? _startRecording : null,
                onLongPressEnd: _msgCtrl.text.trim().isEmpty
                    ? (_) {
                        if (!_isLocked) {
                          _stopRecording(send: true);
                        }
                      }
                    : null,
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : Icon(
                        _msgCtrl.text.trim().isEmpty ? Icons.mic : Icons.send,
                        color: Colors.white,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
