import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api/statut_show.dart';
import '../api/statut_delete.dart';
import '../api/statut_viewers.dart';
import '../widgets/verified_badge.dart';

class StoryViewerPage extends StatefulWidget {
  final int statutId;

  const StoryViewerPage({super.key, required this.statutId});

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage> {
  static const String _baseUrl = "https://zuachat.com/";

  bool _loading = true;
  String? _error;

  /// Tous les statuts du user (triés du plus ancien → au plus récent)
  List<Map<String, dynamic>> _allStatuts = [];
  int _currentStatutIndex = 0;
  int _currentMediaIndex = 0;

  /// Progression du "statut courant" (0 → 1)
  double _progress = 0;
  Timer? _timer;

  // Durée d’affichage d’un statut (ms)
  static const int _totalMs = 5000;
  static const int _tickMs = 50;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ============================================================
  // LOAD
  // ============================================================
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await apiStatutShow(widget.statutId);

      // statut renvoyé (info)
      final current = Map<String, dynamic>.from(data["statut"] ?? {});
      final currentMediasRaw = data["medias"];
      final currentMedias = (currentMediasRaw is List)
          ? currentMediasRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : <Map<String, dynamic>>[];

      // tous les statuts du user (normalement ASC côté PHP)
      final rawAll = data["all_statuts"];
      List<Map<String, dynamic>> all = (rawAll is List)
          ? rawAll.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];

      // fallback : si all_statuts est vide, on reconstruit avec le statut courant
      if (all.isEmpty && current.isNotEmpty) {
        all = [
          {
            ...current,
            "medias": currentMedias,
          }
        ];
      }

      // S’assurer que chaque statut a une liste "medias" + TRIER les médias
      for (var st in all) {
        final rawM = st["medias"];
        List<Map<String, dynamic>> medias = (rawM is List)
            ? rawM.map((m) => Map<String, dynamic>.from(m as Map)).toList()
            : <Map<String, dynamic>>[];

        // tri des médias par created_at ASC (au cas où)
        medias.sort((a, b) {
          final sa = (a["created_at"] ?? "") as String;
          final sb = (b["created_at"] ?? "") as String;
          return sa.compareTo(sb);
        });

        st["medias"] = medias;
      }

      // TRI des statuts par created_at ASC → 10h,11h,12h,13h ...
      all.sort((a, b) {
        final sa = (a["created_at"] ?? "") as String;
        final sb = (b["created_at"] ?? "") as String;
        return sa.compareTo(sb);
      });

      // 🔥 COMPORTEMENT : toujours commencer par le PLUS ANCIEN (index 0)
      setState(() {
        _allStatuts = all;
        _currentStatutIndex = 0;
        _currentMediaIndex = 0;
        _loading = false;
      });

      _startProgress(reset: true);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst("Exception:", "");
        _loading = false;
      });
    }
  }

  // ============================================================
  //  MULTI-PROGRESS (1 barre par STATUT)
  // ============================================================
  Widget _buildProgressBars() {
    final total = _allStatuts.length;
    if (total <= 1) return const SizedBox.shrink();

    return Row(
      children: List.generate(total, (i) {
        double value;
        if (i < _currentStatutIndex) {
          value = 1.0; // statuts déjà passés
        } else if (i == _currentStatutIndex) {
          value = _progress.clamp(0.0, 1.0); // statut courant
        } else {
          value = 0.0; // à venir
        }

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 3,
                backgroundColor: Colors.white24,
                color: Colors.white,
              ),
            ),
          ),
        );
      }),
    );
  }

  // ============================================================
  // PROGRESS AUTOMATIQUE (statut courant)
  // ============================================================
  void _startProgress({bool reset = true}) {
    _timer?.cancel();
    if (reset) _progress = 0;

    if (_allStatuts.isEmpty) return;

    final List medias =
        (_allStatuts[_currentStatutIndex]["medias"] as List?) ?? <dynamic>[];
    if (medias.isEmpty) return;

    final double steps = _totalMs / _tickMs;

    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      setState(() {
        _progress += 1 / steps;
        if (_progress >= 1) {
          _progress = 1;
          t.cancel();
          _nextMedia();
        }
      });
    });
  }

  void _pause() {
    _timer?.cancel();
  }

  void _resume() {
    // Reprend sans réinitialiser _progress
    _startProgress(reset: false);
  }

  // ============================================================
  // NAVIGATION MEDIA
  // ============================================================
  void _nextMedia() {
    final medias =
        (_allStatuts[_currentStatutIndex]["medias"] as List?) ?? <dynamic>[];

    if (_currentMediaIndex < medias.length - 1) {
      setState(() => _currentMediaIndex++);
      _startProgress(reset: true);
    } else {
      _nextStatut();
    }
  }

  void _prevMedia() {
    if (_currentMediaIndex > 0) {
      setState(() => _currentMediaIndex--);
      _startProgress(reset: true);
    } else {
      _prevStatut();
    }
  }

  // ============================================================
  // NAVIGATION STATUT (ancien → récent) 10h → 11h → 12h → 13h
  // ============================================================
  void _nextStatut() {
    if (_currentStatutIndex < _allStatuts.length - 1) {
      setState(() {
        _currentStatutIndex++;
        _currentMediaIndex = 0;
      });
      _startProgress(reset: true);
    } else {
      // dernier statut → retour au feed
      Navigator.pop(context, true);
    }
  }

  void _prevStatut() {
    if (_currentStatutIndex > 0) {
      setState(() {
        _currentStatutIndex--;
        _currentMediaIndex = 0;
      });
      _startProgress(reset: true);
    } else {
      // on quitte si on est déjà au tout premier
      Navigator.pop(context, false);
    }
  }

  // ============================================================
  // DELETE
  // ============================================================
  Future<void> _deleteCurrentStatut() async {
    Navigator.pop(context); // ferme bottom sheet

    final cur = _allStatuts[_currentStatutIndex];
    final int id = (cur["id"] as num?)?.toInt() ?? widget.statutId;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer ce statut ?"),
        content: const Text("Cette action est définitive."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await apiDeleteStatut(id);

    if (!mounted) return;

    setState(() {
      _allStatuts.removeAt(_currentStatutIndex);
      if (_currentStatutIndex >= _allStatuts.length) {
        _currentStatutIndex = _allStatuts.length - 1;
      }
      _currentMediaIndex = 0;
    });

    if (_allStatuts.isEmpty) {
      Navigator.pop(context, true);
      return;
    }

    _startProgress(reset: true);
  }

  // ============================================================
  // MENU OPTIONS
  // ============================================================
  void _openOptions() {
    final cur = _allStatuts[_currentStatutIndex];
    final bool isOwner = (cur["is_owner"] ?? 0) == 1;

    if (!isOwner) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                "Supprimer ce statut",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              onTap: _deleteCurrentStatut,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text("Fermer"),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // VUES : bottom sheet liste des viewers
  // ============================================================
  void _showViewers() {
    final cur = _allStatuts[_currentStatutIndex];
    final bool isOwner = (cur["is_owner"] ?? 0) == 1;
    if (!isOwner) return;

    final int statutId = (cur["id"] as num?)?.toInt() ?? widget.statutId;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: apiStatutViewers(statutId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        snapshot.error
                                ?.toString()
                                .replaceFirst("Exception: ", "") ??
                            "Erreur",
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final viewers = snapshot.data ?? [];

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Text(
                            "${viewers.length} vue${viewers.length > 1 ? 's' : ''}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 1),
                    Expanded(
                      child: viewers.isEmpty
                          ? const Center(
                              child: Text(
                                "Aucune vue",
                                style: TextStyle(
                                  color: Colors.white70,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: viewers.length,
                              itemBuilder: (_, i) {
                                final v = viewers[i];

                                final prenom =
                                    (v["prenom"] ?? "").toString().trim();
                                final nom = (v["nom"] ?? "").toString().trim();
                                final postnom =
                                    (v["postnom"] ?? "").toString().trim();

                                final fullName = [
                                  prenom,
                                  postnom,
                                  nom,
                                ].where((s) => s.isNotEmpty).join(" ");

                                String? photo = v["photo"];
                                if (photo != null &&
                                    photo.isNotEmpty &&
                                    !photo.startsWith("http")) {
                                  photo = "$_baseUrl$photo";
                                }

                                final bool isVerified =
                                    (v["badge_verified"] ?? 0) == 1;

                                ImageProvider<Object> avatar =
                                    (photo != null && photo.isNotEmpty)
                                        ? CachedNetworkImageProvider(photo)
                                        : const AssetImage(
                                                "assets/default-avatar.png")
                                            as ImageProvider<Object>;

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: avatar,
                                    radius: 20,
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          fullName.isEmpty
                                              ? "Utilisateur"
                                              : fullName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      VerifiedBadge.mini(
                                          isVerified: isVerified),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_allStatuts.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            "Aucun média pour ce statut",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final cur = _allStatuts[_currentStatutIndex];
    final List medias = (cur["medias"] as List?) ?? <dynamic>[];

    if (medias.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            "Aucun média pour ce statut",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final media = medias[_currentMediaIndex];
    final type = (media["media_type"] ?? "").toString().toLowerCase();
    final bool isVideo = type.contains("video");

    final rawPath = (media["media_path"] ?? "").toString();
    final mediaUrl = rawPath.startsWith("http") ? rawPath : "$_baseUrl$rawPath";

    final auteur = cur["auteur"] ?? {};
    final time = (cur["time"] ?? "").toString();
    final bool isOwner = (cur["is_owner"] ?? 0) == 1;
    final views = (cur["views"] as num?)?.toInt() ?? 0;

    // avatar sécurisé
    String? photo = auteur["photo"];
    if (photo != null && photo.isNotEmpty && !photo.startsWith("http")) {
      photo = "$_baseUrl$photo";
    }

    ImageProvider<Object> avatar = (photo != null && photo.isNotEmpty)
        ? CachedNetworkImageProvider(photo)
        : const AssetImage("assets/default-avatar.png")
            as ImageProvider<Object>;

    final caption = (media["caption"] ?? "").toString();
    final displayName = isOwner
        ? "Mon statut"
        : "${auteur["prenom"] ?? ""} ${auteur["nom"] ?? ""}";

    final int totalStatuts = _allStatuts.length;
    final int positionStatut = _currentStatutIndex + 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ==================== MEDIA ====================
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: isVideo
                    ? Container(
                        color: Colors.black,
                        child: const Center(
                          child: Icon(
                            Icons.videocam,
                            size: 60,
                            color: Colors.white70,
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: mediaUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white70,
                            size: 40,
                          ),
                        ),
                      ),
              ),
            ),

            // ==================== HEADER + MULTI PROGRESS ====================
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Column(
                children: [
                  _buildProgressBars(),
                  const SizedBox(height: 4),
                  // Statut X sur N
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "Statut $positionStatut sur $totalStatuts",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      CircleAvatar(backgroundImage: avatar, radius: 18),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          if (time.isNotEmpty)
                            Text(
                              time,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      if (isOwner)
                        IconButton(
                          onPressed: _openOptions,
                          icon: const Icon(
                            Icons.more_horiz,
                            color: Colors.white,
                          ),
                        ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ==================== ZONES DE TAP (avec pause long press) ====================
            // ne recouvrent pas header ni caption
            Positioned.fill(
              top: 100,
              bottom: 120,
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _prevMedia,
                      onLongPressStart: (_) => _pause(),
                      onLongPressEnd: (_) => _resume(),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _nextMedia,
                      onLongPressStart: (_) => _pause(),
                      onLongPressEnd: (_) => _resume(),
                    ),
                  ),
                ],
              ),
            ),

            // ==================== CAPTION + VUES ====================
            Positioned(
              left: 20,
              right: 20,
              bottom: 40,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (caption.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        caption,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (isOwner)
                    InkWell(
                      onTap: _showViewers,
                      borderRadius: BorderRadius.circular(999),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.remove_red_eye,
                            color: Colors.white70,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "$views vue${views > 1 ? "s" : ""}",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
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
}
