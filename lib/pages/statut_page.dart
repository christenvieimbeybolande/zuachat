import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api/statut_list.dart';
import 'story_viewer_page.dart';

class StatutPage extends StatefulWidget {
  const StatutPage({super.key});

  @override
  State<StatutPage> createState() => _StatutPageState();
}

class _StatutPageState extends State<StatutPage> {
  final List<Map<String, dynamic>> _groups = [];
  bool _loading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  int _page = 1;
  static const int _limit = 10;
  final ScrollController _scrollController = ScrollController();

  static const String _baseUrl = "https://zuachat.com/";

  @override
  void initState() {
    super.initState();
    _load(reset: true);

    // ---- Détecte si on arrive à la fin du carrousel ----
    _scrollController.addListener(() {
      if (_scrollController.position.maxScrollExtent - _scrollController.position.pixels < 150) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // =============================================================
  // 🔵 CHARGEMENT INITIAL + REFRESH
  // =============================================================
  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _groups.clear();
      _hasMore = true;
    }

    setState(() {
      _loading = reset;
      _error = null;
    });

    try {
      final List<Map<String, dynamic>> res =
          await apiStatutList(page: _page, limit: _limit);

      setState(() {
        _groups.addAll(res);
        _loading = false;
        if (res.length < _limit) _hasMore = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst("Exception:", "");
      });
    }
  }

  // =============================================================
  // 🔵 CHARGEMENT DES PAGES SUIVANTES (INFINITE SCROLL)
  // =============================================================
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    _page++;

    try {
      final res = await apiStatutList(page: _page, limit: _limit);

      setState(() {
        _groups.addAll(res);
        if (res.length < _limit) _hasMore = false;
      });
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  // URL helper
  String fixUrl(String? p) {
    if (p == null || p.isEmpty) return "";
    if (p.startsWith("http")) return p;
    return "$_baseUrl$p";
  }

  // =============================================================
  // 🔵 UI
  // =============================================================
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Statuts")),
        body: Center(
          child: Text(
            "Erreur: $_error",
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Statuts")),

      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 10),

            // =============================================================
            // 🔥 CARROUSEL DES STATUTS AVEC PAGINATION
            // =============================================================
            SizedBox(
              height: 200,
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                itemCount: _groups.length + 1, // +1 → loader à droite
                itemBuilder: (context, index) {
                  if (index == _groups.length) {
                    if (!_hasMore) return const SizedBox.shrink();

                    return Container(
                      width: 100,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    );
                  }

                  final group = Map<String, dynamic>.from(_groups[index]);

                  final user = Map<String, dynamic>.from(group["user"] ?? {});
                  final List statuts = (group["statuts"] is List)
                      ? group["statuts"]
                      : <dynamic>[];

                  if (statuts.isEmpty) return const SizedBox.shrink();

                  final Map<String, dynamic> oldest =
                      Map<String, dynamic>.from(statuts.last);

                  final Map<String, dynamic> newest =
                      Map<String, dynamic>.from(statuts.first);

                  final int statutIdOldest =
                      (oldest["id"] is num) ? (oldest["id"] as num).toInt() : 0;

                  final String preview =
                      fixUrl(newest["media_preview"]?.toString() ?? "");

                  final String photo =
                      fixUrl(user["photo"]?.toString() ?? "");
                  final String prenom = user["prenom"]?.toString() ?? "";
                  final String nom = user["nom"]?.toString() ?? "";

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              StoryViewerPage(statutId: statutIdOldest),
                        ),
                      );
                    },
                    child: Container(
                      width: 120,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: preview.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: preview,
                                    height: 160,
                                    width: 120,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    height: 160,
                                    width: 120,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      image: photo.isNotEmpty
                                          ? DecorationImage(
                                              image:
                                                  CachedNetworkImageProvider(
                                                      photo),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "$prenom $nom",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
