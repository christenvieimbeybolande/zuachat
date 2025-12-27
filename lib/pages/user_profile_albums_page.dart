// lib/pages/user_profile_albums_page.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../api/albums_api.dart';
import '../widgets/zua_loader.dart';
import 'album_photos_page_visitor.dart';

class UserProfileAlbumsPage extends StatefulWidget {
  final int userId;

  const UserProfileAlbumsPage({super.key, required this.userId});

  @override
  State<UserProfileAlbumsPage> createState() => _UserProfileAlbumsPageState();
}

class _UserProfileAlbumsPageState extends State<UserProfileAlbumsPage> {
  bool _loading = true;
  bool _error = false;

  Map<String, dynamic> profil = {};
  Map<String, dynamic> cover = {};
  Map<String, dynamic> allPhotos = {};
  List<Map<String, dynamic>> customAlbums = [];

  static const Color red = Color(0xFFFF0000);
  static const String defaultCover =
      "https://zuachat.com/assets/dossiervide.jpg";

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    final res = await AlbumsApi.fetchUserAlbums(widget.userId);

    if (res['success'] == true) {
      final data = Map<String, dynamic>.from(res['data']);

      profil = Map<String, dynamic>.from(data['profil'] ?? {});
      cover = Map<String, dynamic>.from(data['cover'] ?? {});
      allPhotos = Map<String, dynamic>.from(data['all_photos'] ?? {});
      customAlbums =
          List<Map<String, dynamic>>.from(data['custom_albums'] ?? []);
    } else {
      _error = true;
    }

    if (mounted) setState(() => _loading = false);
  }

  void _openAlbum(String type, {int? id, String? name}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlbumPhotosPageVisitor(
          userId: widget.userId,
          type: type,
          albumId: id,
          albumName: name,
        ),
      ),
    );
  }

  // =========================================================
  // 🖼️ ALBUM CARD (clair / sombre)
  // =========================================================
  Widget _albumCard(
    String title,
    String image,
    int count,
    VoidCallback onTap,
    bool isDark,
  ) {
    final url = image.isEmpty ? defaultCover : image;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: isDark ? 0 : 3,
        color: isDark ? const Color(0xFF242526) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            Expanded(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.grey.shade300),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.broken_image),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$count photo${count > 1 ? 's' : ''}",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // 🧱 BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF18191A) : Colors.white,

      // ================= APPBAR =================
      appBar: AppBar(
        backgroundColor: red,
        foregroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          "Mes albums",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // futur ajout album
            },
          ),
        ],
      ),

      // ================= BODY =================
      body: _loading
          ? const Center(child: ZuaLoader(looping: true))
          : _error
              ? Center(
                  child: TextButton.icon(
                    onPressed: _loadAlbums,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Réessayer"),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAlbums,
                  color: red,
                  child: ListView(
                    children: [
                      const SizedBox(height: 12),

                      // --------- ALBUMS PAR DÉFAUT ----------
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: GridView.count(
                          crossAxisCount: 2,
                          childAspectRatio: 0.78,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _albumCard(
                              "Photos de profil",
                              profil["cover"] ?? defaultCover,
                              profil["count"] ?? 0,
                              () => _openAlbum("profil"),
                              isDark,
                            ),
                            _albumCard(
                              "Photos de couverture",
                              cover["cover"] ?? defaultCover,
                              cover["count"] ?? 0,
                              () => _openAlbum("cover"),
                              isDark,
                            ),
                            _albumCard(
                              "Photos",
                              allPhotos["cover"] ?? defaultCover,
                              allPhotos["count"] ?? 0,
                              () => _openAlbum("all"),
                              isDark,
                            ),
                          ],
                        ),
                      ),

                      // --------- TITRE ----------
                      if (customAlbums.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            "Albums personnalisés",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),

                      // --------- ALBUMS CUSTOM ----------
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.78,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: customAlbums.length,
                          itemBuilder: (_, i) {
                            final a = customAlbums[i];
                            return _albumCard(
                              a["nom"] ?? "Album",
                              a["couverture"] ?? defaultCover,
                              a["count"] ?? 0,
                              () => _openAlbum(
                                "custom",
                                id: a["id"],
                                name: a["nom"],
                              ),
                              isDark,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
