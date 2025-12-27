import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../api/statut_list.dart';
import 'story_viewer_page.dart';

class AllStatusPage extends StatefulWidget {
  const AllStatusPage({super.key});

  @override
  State<AllStatusPage> createState() => _AllStatusPageState();
}

class _AllStatusPageState extends State<AllStatusPage> {
  static const primaryColor = Color(0xFFFF0000);

  bool _loading = false;
  bool _loadingMore = false;
  bool _error = false;

  int _page = 1;
  final int _limit = 20;

  List<Map<String, dynamic>> _groups = [];

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load(initial: true);

    _scrollCtrl.addListener(() {
      if (_loadingMore) return;

      if (_scrollCtrl.position.pixels >
          _scrollCtrl.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ======================================================
  // 🔄 Chargement initial
  // ======================================================
  Future<void> _load({bool initial = false}) async {
    if (initial) {
      setState(() {
        _loading = true;
        _error = false;
        _page = 1;
        _groups.clear();
      });
    }

    try {
      final data = await apiStatutList(page: _page, limit: _limit);

      if (!mounted) return;

      setState(() {
        if (_page == 1) _groups.clear();
        _groups.addAll(
          data.whereType<Map<String, dynamic>>(),
        );
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  // ======================================================
  // ➕ Pagination
  // ======================================================
  Future<void> _loadMore() async {
    if (_loadingMore) return;

    setState(() => _loadingMore = true);
    _page++;

    try {
      final data = await apiStatutList(page: _page, limit: _limit);
      if (mounted) {
        setState(() {
          _groups.addAll(
            data.whereType<Map<String, dynamic>>(),
          );
        });
      }
    } catch (_) {}

    if (mounted) setState(() => _loadingMore = false);
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ---------- LOADING ----------
    if (_loading) {
      return Scaffold(
        appBar: _buildAppBar(theme),
        body: const Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    // ---------- ERREUR ----------
    if (_error) {
      return Scaffold(
        appBar: _buildAppBar(theme),
        body: Center(
          child: ElevatedButton(
            onPressed: () => _load(initial: true),
            child: const Text("Réessayer"),
          ),
        ),
      );
    }

    // ---------- CONTENU ----------
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme),
      body: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(12),
        itemCount: _groups.length + 1,
        itemBuilder: (_, index) {
          if (index == _groups.length) {
            return _loadingMore
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    ),
                  )
                : const SizedBox.shrink();
          }

          final group = _groups[index];
          final user = (group["user"] ?? {}) as Map;
          final List statuts = group["statuts"] ?? [];

          String avatar = user["photo"] ?? "";
          if (avatar.isNotEmpty && !avatar.startsWith("http")) {
            avatar = "https://zuachat.com/$avatar";
          }

          final name = "${user["prenom"] ?? ""} ${user["nom"] ?? ""}".trim();

          // aperçu statut
          String img = "";
          if (statuts.isNotEmpty) {
            img = statuts.first["media_preview"] ?? "";
            if (img.isNotEmpty && !img.startsWith("http")) {
              img = "https://zuachat.com/$img";
            }
          }

          return GestureDetector(
            onTap: () {
              if (statuts.isEmpty) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoryViewerPage(
                    statutId: statuts.first["id"],
                  ),
                ),
              ).then((_) {
                if (mounted) setState(() {});
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 18),
              child: Row(
                children: [
                  // AVATAR + CONTOUR
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: statuts.isNotEmpty
                          ? const LinearGradient(
                              colors: [
                                primaryColor,
                                Color(0xFF42A5F5),
                              ],
                            )
                          : null,
                      border: statuts.isEmpty
                          ? Border.all(
                              color: theme.dividerColor,
                              width: 2,
                            )
                          : null,
                    ),
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: theme.cardColor,
                      backgroundImage: CachedNetworkImageProvider(
                        img.isNotEmpty ? img : avatar,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // NOM
                  Expanded(
                    child: Text(
                      name.isEmpty ? "Utilisateur" : name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  Icon(Icons.chevron_right, color: theme.hintColor),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ======================================================
  // AppBar
  // ======================================================
  AppBar _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      iconTheme: IconThemeData(color: theme.iconTheme.color),
      title: Text(
        "Tous les statuts",
        style: theme.textTheme.titleMedium?.copyWith(
          color: primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
