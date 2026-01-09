import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import '../api/client.dart';
import '../api/fetch_user_profile.dart';
import '../widgets/verified_badge.dart';
import '../widgets/publication_card.dart';
import '../widgets/zua_loader.dart';
import '../widgets/zua_loader_mini.dart';
import '../widgets/bottom_nav.dart';

import 'chat_page.dart';
import 'user_reels_page.dart';
import 'followers_page.dart';
import 'following_page.dart';
import 'user_profile_albums_page.dart';

class UserProfilePage extends StatefulWidget {
  final int userId;
  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _error = false;

  bool _isFollowing = false;
  bool _isFollowedBy = false;
  bool _isBlocked = false;
  bool _checkingBlock = true;

  static const Color _primary = Color(0xFFFF0000);
  static const Color _bg = Color(0xFFF0F2F5);

  Future<Dio> _authed() async => await ApiClient.authed();

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkBlocked();
  }

  Future<void> _checkBlocked() async {
    try {
      final dio = await _authed();
      final res = await dio.get(
        "/is_blocked.php",
        queryParameters: {"user_id": widget.userId},
      );

      if (res.data['ok'] == true) {
        _isBlocked = res.data['blocked'] == true;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _checkingBlock = false);
    }
  }

  Widget _blockedProfileView(bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Column(
          children: [
            Icon(
              Icons.block,
              size: 80,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 20),
            const Text(
              "Profil indisponible",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              "Vous ne pouvez pas voir le contenu de ce profil.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),

            // 🔓 Bouton débloquer si c’est toi qui bloques
            ElevatedButton(
              onPressed: _unblockUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                "Débloquer l’utilisateur",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final res = await fetchUserProfile(widget.userId);

      if (res['success'] == true) {
        if (res['self'] == true) return;

        _isBlocked = res['blocked'] == true;

        _data = {'user': res['user'] ?? {}};
        _data!['publications'] = res['publications'] ?? [];

        _isFollowing = res['is_following'] ?? false;
        _isFollowedBy = res['is_followed_by'] ?? false;
      } else {
        _error = true;
      }
    } catch (e) {
      _error = true;
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _blockUser() async {
    try {
      final dio = await _authed();
      await dio.post("/block_user.php", data: {
        "user_id": widget.userId,
      });

      if (!mounted) return;

      setState(() => _isBlocked = true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Utilisateur bloqué")),
      );
    } catch (_) {}
  }

  Future<void> _unblockUser() async {
    try {
      final dio = await _authed();
      await dio.post("/unblock_user.php", data: {
        "user_id": widget.userId,
      });

      if (!mounted) return;

      setState(() => _isBlocked = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Utilisateur débloqué")),
      );
    } catch (_) {}
  }

  // -------------------------- DOWNLOAD --------------------------

  Future<void> _downloadImage(String url) async {
    try {
      final dio = Dio();
      final resp = await dio.get(url,
          options: Options(responseType: ResponseType.bytes));
      final data = Uint8List.fromList(resp.data);

      await ImageGallerySaverPlus.saveImage(data,
          name: "zuachat_${DateTime.now().millisecondsSinceEpoch}");

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Image enregistrée 🎉")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erreur : $e")));
    }
  }

  void _reportUser() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Signaler ce profil"),
        content: const Text(
          "Ce profil sera signalé à l’équipe de modération.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _sendProfileReport();
            },
            child: const Text("Signaler"),
          ),
        ],
      ),
    );
  }

  Future<void> _sendProfileReport() async {
    try {
      final dio = await _authed();
      await dio.post("/report_user.php", data: {
        "user_id": widget.userId,
        "reason": "abuse",
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profil signalé")),
      );
    } catch (_) {}
  }

  void _openViewer(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: SafeArea(
          child: Stack(
            children: [
              InteractiveViewer(
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: url,
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.broken_image, color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  icon: const Icon(Icons.download, color: Colors.white),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _downloadImage(url);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------- FOLLOW --------------------------

  Future<void> _toggleFollow() async {
    try {
      final dio = await _authed();
      final res = await dio.post(
        "/follow_user.php",
        data: {'target_id': widget.userId},
      );

      if (res.data['success'] == true) {
        setState(() {
          _isFollowing = !_isFollowing;
          if (_isFollowing) _isFollowedBy = false;

          final user = _data!['user'];
          final cur = int.tryParse("${user['followers'] ?? 0}") ?? 0;
          user['followers'] =
              _isFollowing ? (cur + 1).toString() : (cur - 1).toString();
        });
      }
    } catch (_) {}
  }

  // -------------------------- BUILD --------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: ZuaLoader(looping: true)),
      );
    }

    if (_error || _data == null) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: TextButton.icon(
            onPressed: _loadProfile,
            icon: const Icon(Icons.refresh),
            label: const Text("Réessayer"),
          ),
        ),
      );
    }

    final user = _data!['user'];
    final pubs = List<Map<String, dynamic>>.from(_data!['publications'] ?? []);

    final cover = user['couverture'] ??
        "https://zuachat.com/assets/couverture-default.jpg";

    final avatar =
        user['photo'] ?? "https://zuachat.com/assets/default-avatar.png";

    final nom = (user['type_compte'] == "professionnel")
        ? user['nom']
        : "${user['prenom']} ${user['nom']} ${user['postnom']}".trim();

    final username = user['username'] ?? "";

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF18191A) : _bg,
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        color: _primary,
        child: CustomScrollView(
          slivers: [
            // -------------------------- HEADER --------------------------
// -------------------------- HEADER (identique à ProfilePage) --------------------------
            SliverAppBar(
              pinned: true,
              backgroundColor: _primary,
              elevation: 0,
              expandedHeight: MediaQuery.of(context).size.width * 9 / 16,

              // =========================
              // 🔘 MENU (⋮)
              // =========================
              actions: [
                if (!_checkingBlock)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (value) async {
                      if (value == 'block') {
                        await _blockUser();
                      } else if (value == 'unblock') {
                        await _unblockUser();
                      } else if (value == 'report') {
                        _reportUser();
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
                      const PopupMenuItem(
                        value: 'report',
                        child: Text("Signaler ce profil"),
                      ),
                    ],
                  ),
              ],

              // =========================
              // 🎨 CONTENU VISUEL
              // =========================
              flexibleSpace: LayoutBuilder(
                builder: (context, cons) {
                  final raw = (cons.maxHeight - kToolbarHeight) /
                      (260 - kToolbarHeight);
                  final t = raw.isNaN ? 0.0 : raw.clamp(0.0, 1.0);
                  final avatarSize = 120.0 * (0.6 + 0.4 * t);

                  return Stack(
                    clipBehavior: Clip.none,
                    fit: StackFit.expand,
                    children: [
                      // --- IMAGE DE COUVERTURE ---
                      CachedNetworkImage(
                        imageUrl: cover,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: Colors.black26),
                        errorWidget: (_, __, ___) =>
                            Container(color: Colors.black26),
                      ),

                      // --- ZOOM COVER ---
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => _openViewer(cover),
                        ),
                      ),

                      // --- GRADIENT BAS ---
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: 120,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black54],
                            ),
                          ),
                        ),
                      ),

                      // --- AVATAR ---
                      Positioned(
                        bottom: -avatarSize / 2.3,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () => _openViewer(avatar),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: avatarSize / 2,
                                backgroundColor: Colors.white,
                                backgroundImage:
                                    CachedNetworkImageProvider(avatar),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // -------------------------- CARD --------------------------
// -------------------------- CARD PROFIL (identique ProfilePage) --------------------------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 30, 14, 12),
                child: Card(
                  elevation: isDark ? 0 : 2,
                  color: isDark ? const Color(0xFF242526) : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),

                        // --------- NOM + BADGE ----------
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(nom,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            if (user['badge_verified'] == 1) ...[
                              const SizedBox(width: 6),
                              const VerifiedBadge(isVerified: true, size: 18),
                            ]
                          ],
                        ),

                        if (username.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '@$username',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 14),
                            ),
                          ),

                        const SizedBox(height: 12),

                        // --------- BIO ----------
                        Text(
                          (user['bio'] ?? '').isEmpty
                              ? "Aucune bio"
                              : user['bio'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),

                        const SizedBox(height: 14),

// --------- FOLLOWERS / FOLLOWING / PUBLICATIONS / MESSAGE ----------
// --------- FOLLOWERS / FOLLOWING / PUBLICATIONS / MESSAGE (GRID 2x2 PRO) ----------
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Column(
                            children: [
                              // LIGNE 1 : abonnés + abonnements
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => FollowersPage(
                                              userId: widget.userId),
                                        ),
                                      ),
                                      child: _fixedStatButton(
                                        icon: Icons.people,
                                        label: "abonnés",
                                        value: "${user['followers'] ?? 0}",
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => FollowingPage(
                                              userId: widget.userId),
                                        ),
                                      ),
                                      child: _fixedStatButton(
                                        icon: Icons.person_add,
                                        label: "abonnements",
                                        value: "${user['following'] ?? 0}",
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // LIGNE 2 : publications + message
                              Row(
                                children: [
                                  Expanded(
                                    child: _fixedStatButton(
                                      icon: Icons.article,
                                      label: "publications",
                                      value: "${user['publications_total']}",
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ChatPage(
                                              contactId: widget.userId,
                                              contactName:
                                                  "${user['prenom']} ${user['postnom']} ${user['nom']}"
                                                      .trim(),
                                              contactPhoto: user['photo'] ?? "",
                                              badgeVerified:
                                                  user['badge_verified'] == 1,
                                            ),
                                          ),
                                        );
                                      },
                                      child: _fixedStatButton(
                                        icon: Icons.message,
                                        label: "message",
                                        value: "",
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // --------- BOUTON SUIVRE ----------
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _toggleFollow,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _isFollowing ? Colors.grey : _primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              _isFollowing ? "Se désabonner" : "S’abonner",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // --------- INFOS ----------
                        _infoGrid([
                          _infoItem(Icons.phone, user['telephone'] ?? ""),
                          _infoItem(Icons.flag, user['pays'] ?? ""),
                          _infoItem(Icons.wc, user['sexe'] ?? ""),
                          _infoItem(Icons.cake, user['date_naissance'] ?? ""),
                          _infoItem(Icons.account_circle,
                              "Type : ${user['type_compte'] ?? ''}"),
                          if (user['type_compte'] == "professionnel" &&
                              (user['categorie'] ?? "").toString().isNotEmpty)
                            _infoItem(Icons.business_center,
                                "Catégorie : ${user['categorie']}"),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_isBlocked) _blockedProfileView(isDark),
            // -------------------------- TABS --------------------------
            if (!_isBlocked)
              SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _tab("Profil", Icons.grid_view, true, () {}),
                    const SizedBox(width: 8),
                    _tab("Albums", Icons.image, false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              UserProfileAlbumsPage(userId: widget.userId),
                        ),
                      );
                    }),
                    const SizedBox(width: 8),
                    _tab(
                      "Réels",
                      Icons.movie,
                      false,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                UserReelsPage(userId: widget.userId),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

            // -------------------------- PUBLICATIONS --------------------------
            if (!_isBlocked)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                  child: const Text(
                    "Ses publications",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),
            if (!_isBlocked && pubs.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: Text("Aucune publication.")),
                ),
              ),

            if (!_isBlocked && pubs.isNotEmpty)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => PublicationCard(
                    publication: pubs[i],
                    authedDio: _authed,
                    onRefresh: _loadProfile,
                  ),
                  childCount: pubs.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }

  // -------------------------- Widgets --------------------------

  Widget _statChip(IconData icon, String label, String value) {
    return Chip(
      backgroundColor: _primary,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text("$value $label", style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _fixedStatButton({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value.isEmpty ? label : "$value $label",
              style: const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.visible, // 🔥 jamais couper le texte !
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoGrid(List<Widget> children) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }

  Widget _infoItem(IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(10),
      width: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isDark ? const Color(0xFF2A2B2E) : Colors.grey[100],
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: _primary, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text.isEmpty ? "—" : text,
              maxLines: 3,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _tab(String text, IconData icon, bool active, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? _primary
              : (isDark ? const Color(0xFF2A2B2E) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? _primary
                : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: active
                  ? Colors.white
                  : (isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: active
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
