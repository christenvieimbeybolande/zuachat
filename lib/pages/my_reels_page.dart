import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../api/api_fetch_my_reels.dart';
import 'my_reels_viewer_page.dart';
import '../widgets/zua_loader_mini.dart';

class MyReelsPage extends StatefulWidget {
  const MyReelsPage({super.key});

  @override
  State<MyReelsPage> createState() => _MyReelsPageState();
}

class _MyReelsPageState extends State<MyReelsPage> {
  final List<Map<String, dynamic>> reels = [];

  bool loading = true;
  bool error = false;
  bool loadingMore = false;
  bool hasMore = true;

  int page = 1;
  final int limit = 12;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  // ============================================================
  // 🔢 FORMAT COMPTE (identique ReelsPage)
  // ============================================================
  String _formatCount(int n) {
    if (n >= 1000000) {
      final v = n / 1000000.0;
      return v == v.floorToDouble()
          ? "${v.toInt()}M"
          : "${v.toStringAsFixed(1)}M";
    } else if (n >= 1000) {
      final v = n / 1000.0;
      return v == v.floorToDouble()
          ? "${v.toInt()}k"
          : "${v.toStringAsFixed(1)}k";
    }
    return n.toString();
  }

  // ============================================================
  // 📥 CHARGEMENT DES REELS
  // ============================================================
  Future<void> _load({required bool reset}) async {
    if (reset) {
      page = 1;
      reels.clear();
      loading = true;
      error = false;
      hasMore = true;
      setState(() {});
    }

    final res = await apiFetchMyReels(page: page, limit: limit);

    if (!mounted) return;

    if (res["success"] != true) {
      setState(() {
        loading = false;
        error = true;
      });
      return;
    }

    final List<Map<String, dynamic>> list =
        List<Map<String, dynamic>>.from(res["data"] ?? []);

    if (list.length < limit) {
      hasMore = false;
    }

    setState(() {
      loading = false;
      error = false;
      reels.addAll(list);
    });
  }

  // ============================================================
  // ➕ PAGINATION
  // ============================================================
  Future<void> _loadMore() async {
    if (loadingMore || !hasMore || loading) return;

    loadingMore = true;
    page++;
    await _load(reset: false);
    loadingMore = false;
  }

  // ============================================================
  // 🎥 OUVRIR LE VIEWER
  // ============================================================
  Future<void> _openViewer(int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyReelsViewerPage(
          reels: List<Map<String, dynamic>>.from(reels),
          initialIndex: index,
        ),
      ),
    );

    if (result == true) {
      _load(reset: true);
    }
  }

  // ============================================================
  // 🧱 UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Mes Reels",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: loading
          ? const Center(child: ZuaLoaderMini(size: 26))
          : reels.isEmpty
              ? const Center(
                  child: Text(
                    "Vous n’avez encore aucun reel.",
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => _load(reset: true),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(10),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: reels.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      childAspectRatio: 0.75,
                    ),
                    itemBuilder: (_, index) {
                      if (hasMore && index >= reels.length - 3) {
                        _loadMore();
                      }

                      final reel = reels[index];
                      final thumb = (reel["thumbnail"] ?? "").toString();
                      final views = int.tryParse("${reel["views"] ?? 0}") ?? 0;

                      return GestureDetector(
                        onTap: () => _openViewer(index),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              thumb.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: thumb,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(color: Colors.black12),

                              // ▶️ overlay play + vues (PRO)
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.play_arrow,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.remove_red_eye,
                                        color: Colors.white70,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        _formatCount(views),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
