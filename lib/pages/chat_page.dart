import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:vibration/vibration.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/chat_messages.dart';
import '../api/send_chat_message.dart';
import '../api/send_audio_message.dart';
import '../api/delete_chat_message.dart';
import '../api/report_message.dart';
import '../api/block_user.dart';
import '../api/is_blocked.dart';
import '../api/unblock_user.dart';

import '../widgets/chat_audio_bubble.dart';
import '../pages/user_profile.dart';

import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../api/send_file_message.dart';

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
  final Map<int, GlobalKey> _messageKeys = {};

  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _userIsAtBottom() {
    if (!_scrollCtrl.hasClients) return true;
    final pos = _scrollCtrl.position;
    return pos.maxScrollExtent - pos.pixels < 80;
  }

  // =========================
  // 🎙️ AUDIO STATE
  // =========================

  final AudioRecorder _recorder = AudioRecorder();
  Map<String, dynamic>? _replyToMessage;
  int? _highlightedMessageId;
  final ImagePicker _imagePicker = ImagePicker();
  final List<Map<String, dynamic>> _audioQueue = [];
  bool _sendingAudioQueue = false;

  bool _isRecording = false;
  bool _initialScrollDone = false;

  bool _isLocked = false;
  bool _isPaused = false;
  bool _isBlocked = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  Timer? _pollingTimer;

  String? _recordPath;
  final List<Map<String, dynamic>> _sendQueue = [];
  bool _sendingQueue = false;

  bool _loading = true;
  bool _sending = false;
  bool _error = false;
  bool _offline = false;

  DateTime _parseMessageDate(Map m) {
    // adapte si besoin selon ton backend
    return DateTime.parse(m['created_at']);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) return "Aujourd’hui";
    if (d == yesterday) return "Hier";

    final diff = today.difference(d).inDays;

    if (diff < 7) {
      const days = [
        'Lundi',
        'Mardi',
        'Mercredi',
        'Jeudi',
        'Vendredi',
        'Samedi',
        'Dimanche',
      ];
      return days[d.weekday - 1];
    }

    return "${d.day.toString().padLeft(2, '0')}/"
        "${d.month.toString().padLeft(2, '0')}/"
        "${d.year}";
  }

  List<Map<String, dynamic>> _messages = [];
  DateTime? _lastLoadAt;

  @override
  void initState() {
    super.initState();

    _msgCtrl.addListener(() {
      setState(() {});
    });

    // 🔹 Chargement initial
    _load(initial: true);
    _checkBlocked();

    // 🔁 POLLING : recharge les messages toutes les 3 secondes
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        if (!mounted) return;
        if (_offline) {
          _trySendQueuedMessages();
          _trySendQueuedAudios();
          return;
        }

        // ⛔ ne pas recharger pendant un envoi ou un enregistrement
        if (_sending || _isRecording) return;

        _load(scrollToEnd: false);
        _trySendQueuedMessages(); // texte
        _trySendQueuedAudios(); // audio ✅
      },
    );
    // 📡 ÉCOUTE CONNEXION RÉSEAU (AUTO SYNC)
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);

      if (hasConnection && _offline) {
        if (!mounted) return;

        setState(() {
          _offline = false;
        });

        _load(scrollToEnd: false);
        _trySendQueuedMessages();
        _trySendQueuedAudios();
      }

      if (!hasConnection && !_offline) {
        if (!mounted) return;

        setState(() {
          _offline = true;
        });
      }
    });
  }

  void _queueMessage(Map<String, dynamic> msg) {
    _sendQueue.add(msg);
  }

  Future<void> _pickImage() async {
    final XFile? img =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (img == null) return;

    await apiSendFileMessage(
      receiverId: widget.contactId,
      type: 'image',
      file: File(img.path),
      replyTo: _replyToMessage?['id'],
    );

    setState(() => _replyToMessage = null);
  }

  Future<void> _pickVideo() async {
    final XFile? vid =
        await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (vid == null) return;

    await apiSendFileMessage(
      receiverId: widget.contactId,
      type: 'video',
      file: File(vid.path),
      replyTo: _replyToMessage?['id'],
    );

    setState(() => _replyToMessage = null);
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);

    await apiSendFileMessage(
      receiverId: widget.contactId,
      type: 'audio_file',
      file: file,
      replyTo: _replyToMessage?['id'],
    );

    setState(() => _replyToMessage = null);
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'],
    );

    if (result == null || result.files.single.path == null) return;

    await apiSendFileMessage(
      receiverId: widget.contactId,
      type: 'document',
      file: File(result.files.single.path!),
      replyTo: _replyToMessage?['id'],
    );

    setState(() => _replyToMessage = null);
  }

  void _openAttachMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text("Image"),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text("Vidéo"),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.music_note, size: 36),
              title: const Text("Audio (MP3)"),
              onTap: () {
                Navigator.pop(context);
                _pickAudioFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text("Document"),
              onTap: () {
                Navigator.pop(context);
                _pickDocument();
              },
            ),
            ListTile(
              leading: const Icon(Icons.contacts),
              title: const Text("Contact"),
              onTap: () {
                Navigator.pop(context);
                _sendContact();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _trySendQueuedMessages() async {
    if (_sendingQueue) return;
    _sendingQueue = true;
    if (_isBlocked) {
      _audioQueue.clear();
      _sendQueue.clear();
      return;
    }

    while (_sendQueue.isNotEmpty) {
      final msg = _sendQueue.first;

      try {
        await apiSendChatMessage(
          receiverId: widget.contactId,
          message: msg["message"],
          replyTo: _replyToMessage?['id'],
        );

        // ✅ succès → retirer de la queue
        _sendQueue.removeAt(0);
        if (!mounted) return;

        // 🔄 mettre à jour le statut local
        setState(() {
          msg["local_status"] = "sent";
          msg["time"] = "Envoyé";
        });
      } catch (_) {
        // ❌ pas de connexion → on arrête
        break;
      }
    }

    _sendingQueue = false;
  }

  @override
  void dispose() {
    _connectivitySub?.cancel(); // ✅ AJOUT OBLIGATOIRE
    _pollingTimer?.cancel(); // ✅ AJOUT OBLIGATOIRE
    _recordTimer?.cancel();
    _recorder.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendContact() async {
    // 🔹 Exemple simple (plus tard tu peux ouvrir le carnet)
    const name = "Jean Dupont";
    const phone = "+243810000000";

    final vcard = '''
BEGIN:VCARD
VERSION:3.0
FN:$name
TEL:$phone
END:VCARD
''';

    await apiSendChatMessage(
      receiverId: widget.contactId,
      message: vcard,
      type: 'contact',
      replyTo: _replyToMessage?['id'],
    );

    setState(() => _replyToMessage = null);
  }

  Future<void> _checkBlocked() async {
    final blocked = await apiIsBlocked(widget.contactId);
    if (!mounted) return;
    setState(() => _isBlocked = blocked);
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
      _messageKeys.removeWhere(
        (key, _) => !msgs.any(
          (m) => int.parse(m['id'].toString()) == key,
        ),
      );

      setState(() {
        _messages = msgs;
        _loading = false;
      });
      if (scrollToEnd) {
        if (!_initialScrollDone) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _forceScrollToBottom(animated: false);
            _initialScrollDone = true;
          });
        } else {
          _smartScrollToBottom(animated: false);
        }
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _offline = true; // 🔔 SIGNAL OFFLINE
        _loading = false;
      });
    }
  }

  /// 🔽 Scroll forcé (quand MOI j’envoie)
  void _forceScrollToBottom({bool animated = true}) {
    if (!_scrollCtrl.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pos = _scrollCtrl.position.maxScrollExtent;
      animated
          ? _scrollCtrl.animateTo(
              pos,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            )
          : _scrollCtrl.jumpTo(pos);
    });
  }

  /// 🔽 Scroll intelligent (quand message reçu / polling)
  void _smartScrollToBottom({bool animated = true}) {
    if (!_scrollCtrl.hasClients) return;
    if (!_userIsAtBottom()) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pos = _scrollCtrl.position.maxScrollExtent;
      animated
          ? _scrollCtrl.animateTo(
              pos,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            )
          : _scrollCtrl.jumpTo(pos);
    });
  }

  // ============================================================
  // ✉️ Envoyer message
  // ============================================================
  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _msgCtrl.clear();

    final Map<String, dynamic> localMsg = {
      "id": -DateTime.now().millisecondsSinceEpoch,
      "message": text,
      "sender_id": 0,
      "created_at": DateTime.now().toIso8601String(),
      "time": _offline ? "En attente (hors ligne)" : "En attente…",
      "local_status": "pending",
    };

    setState(() {
      _messages.add(localMsg);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forceScrollToBottom();
    });

    // 🔥 FORCER LE SCROLL
    _forceScrollToBottom();

    _queueMessage(localMsg);
    _trySendQueuedMessages();
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
      final Map<String, dynamic> localAudioMsg = {
        "id": -DateTime.now().millisecondsSinceEpoch,
        "type": "voice",
        "audio_path": _recordPath!,
        "audio_duration": _recordDuration.inSeconds,
        "sender_id": 0,
        "created_at": DateTime.now().toIso8601String(),
        "time": _offline ? "En attente (hors ligne)" : "En attente…",
        "local_status": "pending",
        "reply_to": _replyToMessage?['id'],
        "seen": 0,
      };

      setState(() {
        _messages.add(localAudioMsg);
      });

      _audioQueue.add(localAudioMsg);
      _trySendQueuedAudios();

      setState(() => _replyToMessage = null);
    }

    setState(() {
      _isRecording = false;
      _isLocked = false;
      _isPaused = false;
      _recordDuration = Duration.zero;
    });
    _forceScrollToBottom();
  }

  void _scrollToMessage(int messageId) {
    if (!_messageKeys.containsKey(messageId)) return;

    final key = _messageKeys[messageId];
    final context = key?.currentContext;
    if (context == null) return;

    setState(() {
      _highlightedMessageId = messageId;
    });

    Future.delayed(const Duration(milliseconds: 50), () {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted && _highlightedMessageId == messageId) {
        setState(() => _highlightedMessageId = null);
      }
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
  Future<void> _trySendQueuedAudios() async {
    if (_sendingAudioQueue) return;
    _sendingAudioQueue = true;
    if (_isBlocked) {
      _audioQueue.clear();
      _sendQueue.clear();
      return;
    }

    while (_audioQueue.isNotEmpty) {
      final msg = _audioQueue.first;

      try {
        await apiSendAudioMessage(
          receiverId: widget.contactId,
          filePath: msg["audio_path"],
          duration: msg["audio_duration"],
          replyTo: msg["reply_to"],
        );

        _audioQueue.removeAt(0);
        if (!mounted) return;

        setState(() {
          msg["local_status"] = "sent";
          msg["time"] = "Envoyé";
        });
      } catch (_) {
        break; // pas de connexion
      }
    }

    _sendingAudioQueue = false;
  }

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
            // 🚨 SIGNALER MESSAGE (APPLE 1.2)
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.orange),
              title: const Text("Signaler ce message"),
              onTap: () async {
                Navigator.pop(context);

                try {
                  await apiReportMessage(
                    messageId: msg['id'],
                    reason: 'harassment',
                  );

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Message signalé")),
                  );
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Erreur lors du signalement")),
                  );
                }
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

  Widget _replyPreviewBubble(Map m) {
    if (m['reply_to'] == null || m['reply_type'] == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        _scrollToMessage(int.parse(m['reply_to'].toString()));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: primary, width: 3),
          ),
        ),
        child: Text(
          m['reply_type'] == 'voice'
              ? '🎤 Message audio'
              : (m['reply_message'] ?? ''),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  void _openImageViewer(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(url),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 💬 Bulle message (dark / light)
  // ============================================================
  Widget _bubble(Map m) {
    final msgId = int.parse(m['id'].toString());

    _messageKeys.putIfAbsent(
      msgId,
      () => GlobalKey(),
    );

    return Container(
      key: _messageKeys[msgId],
      child: Dismissible(
        key: ValueKey('msg_${m['id']}'),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (_) async {
          setState(() {
            _replyToMessage = Map<String, dynamic>.from(m);
          });
          return false;
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          child: const Icon(Icons.reply, color: Colors.grey),
        ),
        child: _bubbleContent(m),
      ),
    );
  }

  Widget _bubbleContent(Map m) {
    final msgId = int.parse(m['id'].toString());
    final isHighlighted = _highlightedMessageId == msgId;

    final status = m["local_status"];

    if (status == "pending" && m["type"] != "voice") {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.access_time, size: 12, color: Colors.white),
              SizedBox(width: 6),
              Text("En attente…",
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final isMe = _isMe(int.parse("${m['sender_id']}"));
    final deleted = m["deleted_by"] != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final replyBgColor = isMe
        ? Colors.white
        : (isDark ? Colors.grey.shade800 : Colors.grey.shade200);

    final bgColor = deleted
        ? Colors.grey
        : isMe
            ? primary
            : Theme.of(context).cardColor;

    final textColor = deleted
        ? Colors.white
        : isMe
            ? Colors.white
            : Theme.of(context).textTheme.bodyMedium?.color;

    final timeColor = deleted
        ? Colors.white
        : isMe
            ? Colors.white
            : (isDark ? Colors.white54 : Colors.black45);

    // ❌ MESSAGE SUPPRIMÉ
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
    if (m["type"] == "voice" && m["local_status"] == "pending") {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.access_time, size: 14, color: Colors.grey),
            SizedBox(width: 4),
            Text("Audio en attente", style: TextStyle(fontSize: 12)),
          ],
        ),
      );
    }

    // 🔊 AUDIO
    if (m['type'] == 'voice') {
      String rawPath = m['audio_path'].toString().trim();
      rawPath = rawPath
          .replaceAll(RegExp(r'(?<!:)//'), '/')
          .replaceAll('audios/audios', 'audios')
          .replaceAll('uploads/uploads', 'uploads');

      if (!rawPath.startsWith('uploads/')) {
        rawPath = 'uploads/$rawPath';
      }

      final audioUrl =
          rawPath.startsWith('http') ? rawPath : 'https://zuachat.com/$rawPath';

      return Dismissible(
        key: ValueKey('audio_${m['id']}'),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (_) async {
          setState(() {
            _replyToMessage = Map<String, dynamic>.from(m);
          });
          return false;
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          child: const Icon(Icons.reply, color: Colors.grey),
        ),
        child: GestureDetector(
          onLongPress: () => _openOptions(
            msg: m,
            isMe: isMe,
            isAudio: true,
          ),
          child: ChatAudioBubble(
            isMe: isMe,
            url: audioUrl,
            duration: int.tryParse('${m['audio_duration']}') ?? 0,
            time: m['time'] ?? '',
            seen: m['seen'] == 1,
            primaryColor: primary, // 🔥 MÊME ROUGE
            avatarUrl: isMe ? null : widget.contactPhoto,
            replyPreview: _replyPreviewBubble(m),
          ),
        ),
      );
    }
// 🖼️ IMAGE
    if (m['type'] == 'image') {
      final url = _fileUrl(m['file_path']);

      return GestureDetector(
        onLongPress: () => _openOptions(
          msg: m,
          isMe: isMe,
          isAudio: false,
        ),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                _replyPreviewBubble(m),
                GestureDetector(
                  onTap: () => _openImageViewer(url),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      url,
                      width: 220,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        m['time'] ?? '',
                        style: TextStyle(fontSize: 9, color: timeColor),
                      ),
                      const SizedBox(width: 4),
                      _seenIcon(m, isMe),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
// 🎥 VIDEO
    if (m['type'] == 'video') {
      final url = _fileUrl(m['file_path']);

      return GestureDetector(
        onLongPress: () => _openOptions(
          msg: m,
          isMe: isMe,
          isAudio: false,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoPlayerPage(url: url),
            ),
          );
        },
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            width: 220,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const Icon(
                  Icons.play_circle_fill,
                  size: 60,
                  color: Colors.white70,
                ),
                Positioned(
                  bottom: 6,
                  right: 8,
                  child: Row(
                    children: [
                      Text(
                        m['time'] ?? '',
                        style: TextStyle(fontSize: 9, color: timeColor),
                      ),
                      const SizedBox(width: 4),
                      _seenIcon(m, isMe),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      );
    }
// 📇 CONTACT
    if (m['type'] == 'contact') {
      final raw = m['message'] ?? '';

      String name = 'Contact';
      String phone = '';

      for (final line in raw.split('\n')) {
        if (line.startsWith('FN:')) {
          name = line.replaceFirst('FN:', '').trim();
        }
        if (line.startsWith('TEL:')) {
          phone = line.replaceFirst('TEL:', '').trim();
        }
      }

      return GestureDetector(
        onLongPress: () => _openOptions(
          msg: m,
          isMe: isMe,
          isAudio: false,
        ),
        onTap: () async {
          final uri = Uri.parse('tel:$phone');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        },
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_circle, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        phone,
                        style: TextStyle(fontSize: 12, color: timeColor),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      m['time'] ?? '',
                      style: TextStyle(fontSize: 9, color: timeColor),
                    ),
                    _seenIcon(m, isMe),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
// 🎵 AUDIO FILE (MP3)
    if (m['type'] == 'audio_file') {
      final url = _fileUrl(m['file_path']);
      final name = m['file_name'] ?? 'Audio';
      final size = _formatFileSize(m['file_size']);

      return GestureDetector(
        onLongPress: () => _openOptions(
          msg: m,
          isMe: isMe,
          isAudio: false, // ✅ audio_file ≠ voice
        ),
        onTap: () => _openDocument(url),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.audiotrack, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        size,
                        style: TextStyle(fontSize: 11, color: timeColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  children: [
                    Text(
                      m['time'] ?? '',
                      style: TextStyle(fontSize: 9, color: timeColor),
                    ),
                    _seenIcon(m, isMe),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

// 📄 DOCUMENT
    if (m['type'] == 'document') {
      final url = _fileUrl(m['file_path']);
      final name = m['file_name'] ?? 'Document';
      final size = _formatFileSize(m['file_size']);

      return GestureDetector(
        onLongPress: () => _openOptions(
          msg: m,
          isMe: isMe,
          isAudio: false,
        ),
        onTap: () => _openDocument(url),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.insert_drive_file, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        size,
                        style: TextStyle(fontSize: 11, color: timeColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  children: [
                    Text(
                      m['time'] ?? '',
                      style: TextStyle(fontSize: 9, color: timeColor),
                    ),
                    _seenIcon(m, isMe),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 📝 TEXTE
    final text = m["message"] ?? "";
    final time = m["time"] ?? "";

    return GestureDetector(
      onLongPress: () => _openOptions(
        msg: m,
        isMe: isMe,
        isAudio: false,
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
            color: isHighlighted ? Colors.yellow.withOpacity(0.35) : bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // 🔁 MESSAGE RÉPONDU (AFFICHAGE)
              _replyPreviewBubble(m),

              // 📝 MESSAGE PRINCIPAL
              Text(
                text,
                style: TextStyle(color: textColor, fontSize: 14),
              ),

              const SizedBox(height: 4),

              // ⏰ HEURE
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(fontSize: 9, color: timeColor),
                  ),
                  const SizedBox(width: 4),
                  _seenIcon(m, isMe), // ✅ AJOUT
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _seenIcon(Map m, bool isMe) {
    if (!isMe) return const SizedBox.shrink();

    final bool seen = m['seen'] == 1;

    return Icon(
      Icons.done_all,
      size: 14,
      color: seen ? Colors.lightBlueAccent : Colors.white70,
    );
  }

  Widget _replyPreview() {
    if (_replyToMessage == null) return const SizedBox.shrink();
    final type = _replyToMessage!['type'];
    final text = type == 'voice'
        ? "🎤 Message audio"
        : type == 'audio_file'
            ? "🎵 Fichier audio"
            : (_replyToMessage!['message'] ?? '');

    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05), // 🌫️ sombre léger
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: primary, width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Répondre à",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() => _replyToMessage = null);
            },
          ),
        ],
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
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: primary,
        titleSpacing: 0,
        title: _buildHeader(),
        actions: [
          if (_offline)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.cloud_off, color: Colors.white),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _load(scrollToEnd: false),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              if (value == 'block') {
                await apiBlockUser(widget.contactId);
                if (!mounted) return;
                setState(() => _isBlocked = true);
              }

              if (value == 'unblock') {
                await apiUnblockUser(widget.contactId);
                if (!mounted) return;
                setState(() => _isBlocked = false);
              }
            },
            itemBuilder: (_) => [
              if (!_isBlocked)
                const PopupMenuItem(
                  value: 'block',
                  child: Text("Bloquer l’utilisateur"),
                ),
              if (_isBlocked)
                const PopupMenuItem(
                  value: 'unblock',
                  child: Text("Débloquer l’utilisateur"),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _recordingOverlay(),
          // 🔔 BANNIÈRE OFFLINE
          if (_offline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: Colors.orange.shade200,
              child: const Text(
                "Hors connexion, messages en attente",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
          Expanded(
            child: Builder(
              builder: (_) {
                if (_loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(10),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final msg = _messages[i];
                    final msgDate = _parseMessageDate(msg);

                    bool showHeader;

                    // 🔹 Premier message de la liste → TOUJOURS afficher date
                    if (i == 0) {
                      showHeader = true;
                    } else {
                      final prevMsg = _messages[i - 1];
                      final prevDate = _parseMessageDate(prevMsg);

                      // 🔹 Si le jour change entre le message précédent et celui-ci
                      showHeader = !_isSameDay(msgDate, prevDate);
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showHeader) _dateHeader(_formatDateHeader(msgDate)),
                        _bubble(msg),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _replyPreview(),
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
      color: primary.withOpacity(0.95),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
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
            icon: const Icon(Icons.send, color: Color.fromARGB(255, 255, 0, 0)),
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
    if (_isBlocked) {
      return Container(
        padding: const EdgeInsets.all(12),
        color: Colors.grey.shade200,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Utilisateur bloqué",
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () async {
                await apiUnblockUser(widget.contactId);
                if (!mounted) return;
                setState(() => _isBlocked = false);
              },
              child: const Text("Débloquer"),
            )
          ],
        ),
      );
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        color: Theme.of(context).cardColor,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _openAttachMenu,
            ),
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                minLines: 1,
                maxLines: 4,

                // ✅ DÉBUT EN MAJUSCULE POUR LE PREMIER MOT
                textCapitalization: TextCapitalization.sentences,

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
            if (_msgCtrl.text.trim().isEmpty)
              IconButton(
                icon: const Icon(Icons.photo),
                onPressed: _pickImage,
              ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: _isRecording ? Colors.red : primary,
              child: GestureDetector(
                onTap: () async {
                  // 📝 TEXTE → ENVOYER
                  if (_msgCtrl.text.trim().isNotEmpty) {
                    if (!_sending) _send();
                    return;
                  }

                  // 🎙️ AUDIO
                  if (!_isRecording) {
                    await _startRecording(); // ▶️ start
                  } else {
                    await _stopRecording(send: true); // ⏹️ stop + send
                  }
                },
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : Icon(
                        _msgCtrl.text.trim().isNotEmpty
                            ? Icons.send
                            : _isRecording
                                ? Icons.send // 🔴 pendant enregistrement
                                : Icons.mic,
                        color: Colors.white,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fileUrl(String path) {
    if (path.startsWith('http')) return path;
    return 'https://zuachat.com/$path';
  }

  String _formatFileSize(int? size) {
    if (size == null) return '';
    if (size < 1024) return '$size o';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} Ko';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }
}

class VideoPlayerPage extends StatefulWidget {
  final String url;
  const VideoPlayerPage({super.key, required this.url});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

Future<void> _openDocument(String url) async {
  final uri = Uri.parse(url);

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
