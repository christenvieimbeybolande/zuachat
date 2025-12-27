import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/chat_messages.dart';
import '../api/send_chat_message.dart';
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
  static const primary = Color(0xFFFF0000);

  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

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

  bool _isMe(int senderId) => senderId != widget.contactId;

  // ============================================================
  // 📌 Options message
  // ============================================================
  void _openOptions(Map msg, bool isMe) {
    if (msg["deleted_by"] != null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
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
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text("Supprimer pour moi"),
              onTap: () async {
                Navigator.pop(context);
                await apiDeleteMessage(msg["id"], forAll: false);
                _load();
              },
            ),
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

    final text = deleted ? "Message supprimé" : (m["message"] ?? "");
    final time = m["time"] ?? "";

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onLongPress: deleted ? null : () => _openOptions(m, isMe),
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
              child: IconButton(
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: _sending ? null : _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
