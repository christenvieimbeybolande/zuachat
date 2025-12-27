import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/verified_badge.dart';
import '../api/client.dart';
import '../pages/profile_page.dart';
import '../pages/user_profile.dart';

class ReactionsPage extends StatefulWidget {
  final int publicationId;
  final int totalCount;
  final Map<String, dynamic>? reactionSummary;
  final List<Map<String, dynamic>> users;

  const ReactionsPage({
    super.key,
    required this.publicationId,
    required this.totalCount,
    required this.users,
    this.reactionSummary,
  });

  @override
  State<ReactionsPage> createState() => _ReactionsPageState();
}

class _ReactionsPageState extends State<ReactionsPage> {
  static const red = Color(0xFFFF0000);

  List<Map<String, dynamic>> _users = [];
  String _search = '';
  String? _filterEmoji;
  int? _currentUserId;

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _users = widget.users.map((e) => Map<String, dynamic>.from(e)).toList();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = int.tryParse(prefs.getString('user_id') ?? '0');
    });
  }

  String _formatCount(int n) {
    if (n >= 1000000) {
      final v = (n / 1000000).toStringAsFixed(1);
      return v.endsWith('.0') ? "${v.substring(0, v.length - 2)}M" : "${v}M";
    }
    if (n >= 1000) {
      final v = (n / 1000).toStringAsFixed(1);
      return v.endsWith('.0') ? "${v.substring(0, v.length - 2)}k" : "${v}k";
    }
    return n.toString();
  }

  bool _isFollowing(Map<String, dynamic> u) {
    final v = u['is_following'];
    return v == true || v == 1 || v == '1';
  }

  Future<void> _toggleFollow(Map<String, dynamic> u) async {
    final userId = int.tryParse("${u['user_id']}") ?? 0;
    if (userId <= 0) return;

    try {
      final dio = await ApiClient.authed();
      await dio.post('/follow_user.php', data: {'target_id': userId});
      setState(() => u['is_following'] = !_isFollowing(u));
    } catch (_) {}
  }

  void _openProfile(int userId) {
    if (_currentUserId == userId) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const ProfilePage()));
    } else {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => UserProfilePage(userId: userId)));
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    var list = _users;

    if (_filterEmoji != null && _filterEmoji!.isNotEmpty) {
      list = list.where((u) => u['emoji'] == _filterEmoji).toList();
    }

    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((u) {
        final prenom = (u['prenom'] ?? '').toLowerCase();
        final nom = (u['nom'] ?? '').toLowerCase();
        final postnom = (u['postnom'] ?? '').toLowerCase();
        final username = (u['username'] ?? '').toLowerCase();
        return "$prenom $nom $postnom $username".contains(q);
      }).toList();
    }

    return list;
  }

  Widget _emojiButton(String? emoji, int count) {
    final active = _filterEmoji == emoji;

    return GestureDetector(
      onTap: () => setState(() => _filterEmoji = emoji),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? red.withOpacity(0.2)
              : (isDark ? const Color(0xFF242526) : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? red : Colors.grey.shade400,
          ),
        ),
        child: Column(
          children: [
            Text(
              emoji ?? "✓",
              style: TextStyle(
                fontSize: emoji == null ? 16 : 20,
                color: active ? red : (isDark ? Colors.white : Colors.black),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatCount(count),
              style: TextStyle(
                fontSize: 12,
                color: active ? red : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.reactionSummary ?? {};

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF18191A) : Colors.white,
      appBar: AppBar(
        backgroundColor: red,
        foregroundColor: Colors.white,
        title: Text(
          "Réactions (${widget.totalCount})",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 6),

          // 🔥 Filtres emoji
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _emojiButton(null, widget.totalCount),
                _emojiButton("❤️", summary["❤️"] ?? 0),
                _emojiButton("👍", summary["👍"] ?? 0),
                _emojiButton("😂", summary["😂"] ?? 0),
                _emojiButton("😮", summary["😮"] ?? 0),
              ],
            ),
          ),

          // 🔎 Recherche
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: "Rechercher dans les réactions...",
                hintStyle:
                    TextStyle(color: isDark ? Colors.white60 : Colors.grey),
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF242526) : Colors.grey.shade200,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: _filteredUsers.isEmpty
                ? const Center(
                    child: Text("Aucune réaction.",
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    itemCount: _filteredUsers.length,
                    itemBuilder: (_, i) {
                      final u = _filteredUsers[i];
                      final userId = int.tryParse("${u['user_id']}") ?? 0;

                      final fullName = [
                        u['prenom'] ?? "",
                        u['nom'] ?? "",
                        u['postnom'] ?? ""
                      ].where((x) => x.toString().isNotEmpty).join(" ");

                      final avatar = (u['photo'] ?? '').toString().isEmpty
                          ? "https://zuachat.com/assets/default-avatar.png"
                          : u['photo'];

                      return Card(
                        color: isDark ? const Color(0xFF242526) : Colors.white,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _openProfile(userId),
                                child: CircleAvatar(
                                  radius: 25,
                                  backgroundImage:
                                      CachedNetworkImageProvider(avatar),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            fullName.isEmpty
                                                ? (u['username'] ??
                                                    "Utilisateur")
                                                : fullName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        if (u['badge_verified'] == 1 ||
                                            u['badge_verified'] == '1')
                                          const VerifiedBadge(
                                              isVerified: true, size: 17),
                                      ],
                                    ),
                                    Text(
                                      "@${u['username']}",
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Text(u['emoji'] ?? "",
                                      style: const TextStyle(fontSize: 22)),
                                  const SizedBox(height: 6),
                                  if (_currentUserId != userId)
                                    ElevatedButton(
                                      onPressed: () => _toggleFollow(u),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            _isFollowing(u) ? Colors.grey : red,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(90, 28),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                      ),
                                      child: Text(
                                        _isFollowing(u)
                                            ? "Abonné"
                                            : "S’abonner",
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                ],
                              ),
                            ],
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
