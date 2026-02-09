import 'dart:async'; // ✅ OBLIGATOIRE POUR Timer
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../api/messages_list.dart';
import '../api/friends_for_chat.dart';
import '../api/delete_conversation.dart';
import 'chat_page.dart';
import 'user_profile.dart';

class MessageListPage extends StatefulWidget {
  const MessageListPage({super.key});

  @override
  State<MessageListPage> createState() => _MessageListPageState();
}

class _MessageListPageState extends State<MessageListPage> {
  static const primary = Color(0xFFFF0000);
  Timer? _pollingTimer;

  // ======================================================
  // ⏱️ Format "il y a 5 min / hier / il y a 3 jours / date"
  // ======================================================
  String formatTimeAgo(String raw) {
    if (raw.isEmpty) return "";

    DateTime time;
    try {
      time = DateTime.parse(raw);
    } catch (_) {
      // Si jamais le format ne passe pas -> on renvoie le texte original
      return raw;
    }

    final diff = DateTime.now().difference(time);

    if (diff.inSeconds < 30) return "À l’instant";
    if (diff.inMinutes < 1) return "Il y a moins d’une minute";
    if (diff.inMinutes < 60) return "Il y a ${diff.inMinutes} min";
    if (diff.inHours < 24) return "Il y a ${diff.inHours} h";

    if (diff.inDays == 1) return "Hier";
    if (diff.inDays < 7) return "Il y a ${diff.inDays} jours";

    // Si > 7 jours : afficher la date simple
    return "${time.day.toString().padLeft(2, '0')}/"
        "${time.month.toString().padLeft(2, '0')}/"
        "${time.year}";
  }

  bool _loading = true;
  bool _error = false;
  List<Map<String, dynamic>> _conversations = [];

  @override
  void initState() {
    super.initState();

    _load(); // ✅ chargement initial SEULEMENT

    // 🔁 POLLING SILENCIEUX (temps réel sans clignotement)
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (!mounted) return;
        _pollSilent(); // ✅ IMPORTANT
      },
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel(); // ✅ TRÈS IMPORTANT
    super.dispose();
  }

  // ======================================================
  // 🔕 Polling SILENCIEUX (basé sur last_msg_time)
  // ======================================================
  Future<void> _pollSilent() async {
    try {
      final data = await apiFetchConversations();
      if (!mounted) return;

      final oldTime = _conversations.isNotEmpty
          ? _conversations.first['last_msg_time']
          : null;

      final newTime = data.isNotEmpty ? data.first['last_msg_time'] : null;

      // 🔥 Mise à jour UNIQUEMENT s’il y a un nouveau message
      if (oldTime != newTime) {
        setState(() {
          _conversations = data;
        });
      }
    } catch (_) {
      // silence total (pas d'UI impactée)
    }
  }

  // ======================================================
  // 🔄 Charger les conversations
  // ======================================================
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final data = await apiFetchConversations();
      if (!mounted) return;

      setState(() {
        _conversations = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  // ======================================================
  // ❌ Menu suppression conversation
  // ======================================================
  void _openDeleteMenu(int partnerId, String fullname) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text("Supprimer la conversation avec $fullname"),
                onTap: () async {
                  Navigator.pop(context);

                  final ok = await apiDeleteConversation(partnerId);
                  if (ok) {
                    _load();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ======================================================
  // 📱 Nouveau message (liste de contacts)
  // ======================================================
  Future<void> _openNewMessageModal() async {
    try {
      final friends = await apiFetchFriendsForChat();
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          final TextEditingController searchCtrl = TextEditingController();
          List<Map<String, dynamic>> filtered = List.of(friends);

          return StatefulBuilder(
            builder: (context, setStateModal) {
              void localSearch(String q) {
                final lower = q.toLowerCase();
                setStateModal(() {
                  filtered = friends.where((f) {
                    final full =
                        "${f['prenom'] ?? ''} ${f['postnom'] ?? ''} ${f['nom'] ?? ''}"
                            .toLowerCase();
                    return full.contains(lower);
                  }).toList();
                });
              }

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 12,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: SizedBox(
                          width: 40,
                          child: Divider(thickness: 3),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Nouveau message",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: searchCtrl,
                        onChanged: localSearch,
                        decoration: InputDecoration(
                          hintText: "Rechercher un contact...",
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text("Aucun contact trouvé",
                                    style: TextStyle(color: Colors.grey)),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final f = filtered[i];
                                  final int id =
                                      int.tryParse("${f['id']}") ?? 0;

                                  final fullname =
                                      "${f['prenom'] ?? ''} ${f['postnom'] ?? ''} ${f['nom'] ?? ''}"
                                          .trim();

                                  String photo = f["photo"] ?? "";
                                  if (photo.isNotEmpty &&
                                      !photo.startsWith("http")) {
                                    photo = "https://zuachat.com/$photo";
                                  }

                                  final verified =
                                      f["badge_verified"].toString() == "1";

                                  return ListTile(
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChatPage(
                                            contactId: id,
                                            contactName: fullname,
                                            contactPhoto: photo,
                                            badgeVerified: verified,
                                          ),
                                        ),
                                      );
                                    },
                                    leading: CircleAvatar(
                                      backgroundImage: (photo.isNotEmpty
                                          ? CachedNetworkImageProvider(photo)
                                          : const AssetImage(
                                                  "assets/default-avatar.png")
                                              as ImageProvider),
                                    ),
                                    title: Text(fullname),
                                    trailing: verified
                                        ? const Icon(Icons.verified,
                                            color: Colors.blue, size: 18)
                                        : null,
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  // ======================================================
  // 🖥️ UI PRINCIPALE
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        title: const Text("Messages", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load)
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primary,
        onPressed: _openNewMessageModal,
        child: const Icon(Icons.edit),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: primary,
        child: Builder(
          builder: (context) {
            // ⏳ Chargement
            if (_loading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            // ❌ Erreur
            if (_error) {
              return Center(
                child: ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Réessayer"),
                ),
              );
            }

            // 📭 Aucune conversation
            if (_conversations.isEmpty) {
              return Center(
                child: Text(
                  "Aucune conversation pour l’instant.",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            }

            // 📬 Liste des conversations
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _conversations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = _conversations[i];

                final int partnerId = c["partner_id"];
                final String fullname = c["fullname"] ?? "";
                final String photo = c["photo"] ?? "";
                final bool verified = c["badge_verified"].toString() == "1";
                final int unread = int.tryParse("${c["unread_count"]}") ?? 0;
                final String lastTimeRaw =
                    (c["last_msg_time"] ?? "").toString();

                return GestureDetector(
                  onLongPress: () => _openDeleteMenu(partnerId, fullname),
                  child: Material(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              contactId: partnerId,
                              contactName: fullname,
                              contactPhoto: photo,
                              badgeVerified: verified,
                            ),
                          ),
                        ).then((_) => _load());
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage:
                                  CachedNetworkImageProvider(photo),
                            ),
                            const SizedBox(width: 12),

                            // Nom + date
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          fullname,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (verified)
                                        const Icon(
                                          Icons.verified,
                                          size: 16,
                                          color: Colors.blue,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    lastTimeRaw.isNotEmpty
                                        ? "Dernier message • ${formatTimeAgo(lastTimeRaw)}"
                                        : "Conversation",
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),

                            // Badge non lus
                            if (unread > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "$unread",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
