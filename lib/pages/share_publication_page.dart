import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../api/fetch_shareable_users.dart';
import '../api/api_share_publication.dart';

class SharePublicationPage extends StatefulWidget {
  final int publicationId;

  const SharePublicationPage({
    super.key,
    required this.publicationId,
  });

  @override
  State<SharePublicationPage> createState() => _SharePublicationPageState();
}

class _SharePublicationPageState extends State<SharePublicationPage> {
  static const Color primary = Color(0xFFFF0000);
  static const String defaultAvatar =
      'https://zuachat.com/assets/default-avatar.png';

  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> filtered = [];
  bool loading = true;
  String query = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  // =========================================================
  // 📡 Charger utilisateurs partageables
  // =========================================================
  Future<void> _loadUsers() async {
    final res = await fetchShareableUsers();

    setState(() {
      users = res;
      filtered = res;
      loading = false;
    });
  }

  // =========================================================
  // 🔍 Recherche
  // =========================================================
  void _search(String q) {
    setState(() {
      query = q;
      filtered = users.where((u) {
        final name =
            '${u['prenom'] ?? ''} ${u['nom'] ?? ''} ${u['username'] ?? ''}'
                .toLowerCase();
        return name.contains(q.toLowerCase());
      }).toList();
    });
  }

  // =========================================================
  // 📤 Partager
  // =========================================================
  Future<void> _shareToUser(Map<String, dynamic> user) async {
    final res = await sharePublication(
      publicationId: widget.publicationId,
      receiverId: user['id'],
    );

    if (res['success'] == true) {
      Fluttertoast.showToast(msg: "Publication partagée ");
      Navigator.pop(context, true);
    } else {
      Fluttertoast.showToast(
        msg: res['message'] ?? "Erreur de partage",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // =========================================================
  // 🧱 UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // ---------------- APPBAR ----------------
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        title: const Text(
          "Partager",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // ---------------- BODY ----------------
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 🔍 SEARCH
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: TextField(
                    onChanged: _search,
                    decoration: InputDecoration(
                      hintText: "Rechercher un utilisateur…",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),

                // 👥 LISTE UTILISATEURS
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            "Aucun utilisateur trouvé",
                            style: TextStyle(fontSize: 15),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final u = filtered[i];

                            final String avatar = (u['photo'] != null &&
                                    u['photo'].toString().isNotEmpty)
                                ? u['photo']
                                : defaultAvatar;

                            return ListTile(
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundImage:
                                    CachedNetworkImageProvider(avatar),
                              ),
                              title: Text(
                                '${u['prenom'] ?? ''} ${u['nom'] ?? ''}'.trim(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text('@${u['username'] ?? ''}'.trim()),
                              trailing: ElevatedButton.icon(
                                onPressed: () => _shareToUser(u),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                icon: const Icon(Icons.send,
                                    size: 18, color: Colors.white),
                                label: const Text(
                                  "Envoyer",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
