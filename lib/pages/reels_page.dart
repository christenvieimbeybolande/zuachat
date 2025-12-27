import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io'; // 🔥 pour File
import 'package:path_provider/path_provider.dart'; // 🔥 pour getDownloadsDirectory
import 'package:wakelock_plus/wakelock_plus.dart';

import '../api/fetch_reels.dart';
import '../api/react_publication.dart';
import '../api/comments.dart';
import '../api/react_comment.dart';
import '../widgets/zua_loader_mini.dart';
import '../widgets/verified_badge.dart';
import 'profile_page.dart';
import 'user_profile.dart';
import '../api/api_add_reel_view.dart';

class ReelsPage extends StatefulWidget {
  /// id de la publication reel à ouvrir en premier
  /// 0 = on commence au début
  final int initialReelId;

  const ReelsPage({
    super.key,
    required this.initialReelId,
  });

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  final PageController _pageController = PageController();

  // 👁️ reels déjà vus (anti doublon)
  final Set<int> _viewedReels = {};

  final List<Map<String, dynamic>> _reels = [];
  VideoPlayerController? _currentPlayer;
  int? _currentReelId;

  VideoPlayerController? _preloadPlayer;
  int? _preloadIndex;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  bool _loading = true;
  bool _error = false;
  bool _loadingMore = false;
  bool _downloading = false;
  double _downloadProgress = 0.0;

  int _page = 1;
  final int _limit = 8; // 🔥 8 reels par page (comme demandé)
  int _currentIndex = 0;
  bool _soundOn = true;
  Duration _currentPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;
  bool _isDraggingSlider = false;

  // =======================
  // 💬 Etat des commentaires
  // =======================
  bool _showComments = false;
  int? _commentsPubId;
  int? _commentsReelIndex;
  List<dynamic> _comments = [];
  bool _loadingComments = false;
  bool _sendingComment = false;
  int? _replyTo;
  final Set<int> _expandedComments = {};
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  VoidCallback? _videoListener;

  int? _userId; // pour savoir si c’est mon commentaire (edit/suppr)

  @override
  void initState() {
    super.initState();
    _loadMyId();
    _loadPage(reset: true);
  }

  Future<void> _loadMyId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idStr = prefs.getString('user_id') ?? '';
      setState(() {
        _userId = int.tryParse(idStr);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    // 🔥 sécurité absolue
    WakelockPlus.disable();

    if (_videoListener != null && _currentPlayer != null) {
      _currentPlayer!.removeListener(_videoListener!);
    }
    _currentPlayer?.dispose();

    _preloadPlayer?.dispose();
    _pageController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _openProfile(Map<String, dynamic> auteur) async {
    // 1️⃣ arrêter la vidéo
    if (_currentPlayer != null) {
      await _currentPlayer!.pause();
    }

    final prefs = await SharedPreferences.getInstance();
    final myId = int.tryParse(prefs.getString('user_id') ?? '0') ?? 0;

    final int userId = int.tryParse("${auteur['id']}") ?? 0;

    if (userId == 0) return;

    // 2️⃣ navigation
    if (userId == myId) {
      // 👉 mon propre profil
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
    } else {
      // 👉 autre utilisateur
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfilePage(userId: userId),
        ),
      );
    }
  }

  // ============================================================
  // 🔥 CHARGEMENT DES REELS (PAGINATION 8 par 8)
  // ============================================================
  Future<void> _loadPage({required bool reset}) async {
    if (reset) {
      _page = 1;
      _reels.clear();
      setState(() {
        _loading = true;
        _error = false;
      });
    }

    final res = await fetchReels(page: _page, limit: _limit);

    if (res["success"] != true) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
      return;
    }

    final List<Map<String, dynamic>> newReels =
        List<Map<String, dynamic>>.from(res["data"] ?? []);
    if (newReels.isEmpty) {
      setState(() {
        _loading = false;
        _error = false;
      });
      return;
    }

    // aucune donnée
    if (newReels.isEmpty && _reels.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = false;
        });
      }
      return;
    }

    // Ajout sans doublons
    for (final raw in newReels) {
      final reel = Map<String, dynamic>.from(raw);
      final id = int.tryParse("${reel["id"]}") ?? 0;
      if (id == 0) continue;
      if (_reels.any((r) => int.tryParse("${r["id"]}") == id)) continue;
      _reels.add(reel);
    }

    if (!mounted) return;

    setState(() {
      _loading = false;
      _error = false;
    });

    // Auto-focus sur le reel ciblé
    if (reset && _reels.isNotEmpty) {
      int startIndex = 0;

      if (widget.initialReelId != 0) {
        final idx = _reels.indexWhere(
          (r) => int.tryParse("${r["id"]}") == widget.initialReelId,
        );
        if (idx >= 0) {
          startIndex = idx;
        }
      }

      _currentIndex = startIndex;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!_pageController.hasClients) return;

        _pageController.jumpToPage(startIndex);

        // 🔥 démarrage immédiat
        await _playReel(startIndex);
      });
    } else {
      if (_currentIndex >= 0 && _currentIndex < _reels.length) {
        _playReel(_currentIndex);
      }
    }
  }

  Future<void> _toggleSound() async {
    _soundOn = !_soundOn;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reels_sound', _soundOn);

    _currentPlayer?.setVolume(_soundOn ? 1.0 : 0.0);
    setState(() {});
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    _loadingMore = true;
    _page++;
    await _loadPage(reset: false);
    _loadingMore = false;
  }

  // ============================================================
  // 🎥 GESTION VIDEO (preload + cleanup)
  // ============================================================

  Future<void> _playReel(int index) async {
    if (index < 0 || index >= _reels.length) return;

    if (_currentReelId == _reels[index]["id"]) return;

    final reel = _reels[index];
    final videoUrl = reel["video"]?.toString() ?? "";
    if (videoUrl.isEmpty) return;

// 🔥 libérer l’écran pour l’ancien reel
    await WakelockPlus.disable();
    if (_videoListener != null && _currentPlayer != null) {
      _currentPlayer!.removeListener(_videoListener!);
    }

    _currentPlayer?.pause();
    _currentPlayer?.dispose();

    // ✅ si déjà préchargé
    if (_preloadIndex == index && _preloadPlayer != null) {
      _currentPlayer = _preloadPlayer;
      _preloadPlayer = null;
      _preloadIndex = null;
      setState(() {
        _currentPosition = Duration.zero;
        _videoDuration = _currentPlayer!.value.duration;
      });

      _videoListener = () {
        if (!mounted) return;

        final v = _currentPlayer!.value;
        if (!v.isInitialized) return;

        if (!_isDraggingSlider) {
          setState(() {
            _currentPosition = v.position;
            _videoDuration = v.duration;
          });
        }
      };

      _currentPlayer!.addListener(_videoListener!);
    } else {
      _currentPlayer = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _currentPlayer!.initialize();
      setState(() {
        _currentPosition = Duration.zero;
        _videoDuration = _currentPlayer!.value.duration;
      });
      _videoListener = () {
        if (!mounted) return;

        final v = _currentPlayer!.value;
        if (!v.isInitialized) return;

        if (!_isDraggingSlider) {
          setState(() {
            _currentPosition = v.position;
            _videoDuration = v.duration;
          });
        }
      };

      _currentPlayer!.addListener(_videoListener!);
    }

    _currentPlayer!.setLooping(true);
    _currentPlayer!.setVolume(_soundOn ? 1.0 : 0.0);
    _isDraggingSlider = false;

    await _currentPlayer!.play();

    await WakelockPlus.enable();

    setState(() {
      _currentReelId = reel["id"];
    });

    // ===========================
// 👁️ AJOUT DE VUE (SAFE)
// ===========================
    final reelId = int.tryParse("${reel["id"]}") ?? 0;

    if (reelId > 0 && !_viewedReels.contains(reelId)) {
      _viewedReels.add(reelId);

      // ⏱️ attendre un peu pour éviter scroll rapide
      Future.delayed(const Duration(milliseconds: 1500), () async {
        if (!mounted) return;
        if (_currentIndex != index) return;

        try {
          await apiAddReelView(reelId);

          // MAJ locale du compteur
          setState(() {
            reel["views"] = (int.tryParse("${reel["views"] ?? 0}") ?? 0) + 1;
          });
        } catch (_) {
          // silencieux (pas bloquant)
        }
      });
    }

    // 🔥 précharge le prochain
    _preloadNextReel(index);
  }

  Future<void> _preloadNextReel(int index) async {
    final nextIndex = index + 1;
    if (nextIndex < 0 || nextIndex >= _reels.length) return;
    if (_preloadIndex == nextIndex) return;

    final reel = _reels[nextIndex];
    final url = reel["video"]?.toString() ?? "";
    if (url.isEmpty) return;

    try {
      _preloadPlayer?.dispose();
      _preloadPlayer = VideoPlayerController.networkUrl(Uri.parse(url));
      await _preloadPlayer!.initialize();
      _preloadPlayer!.setVolume(0.0);
      _preloadIndex = nextIndex;
    } catch (_) {}
  }

  // ============================================================
  // ❤️ LIKE (synchro avec feed)
  // ============================================================
  Future<void> _toggleLike(int index) async {
    if (index < 0 || index >= _reels.length) return;
    final reel = _reels[index];
    final pubId = int.tryParse("${reel["id"]}") ?? 0;

    final emoji =
        "❤️"; // 👍 tu peux changer, mais ❤️ donne un meilleur effet TikTok

    try {
      final res = await apiReactToPublication(
        publicationId: pubId,
        emoji: emoji,
      );

      setState(() {
        reel["liked"] = !res["removed"];
        reel["my_emoji"] = res["removed"] ? null : emoji;
        reel["likes"] = res["count"];
      });
    } catch (e) {
      Fluttertoast.showToast(msg: "Erreur like");
    }
  }

  void _openReelOptions(int index) {
    final reel = _reels[index];
    final videoUrl = (reel["video"] ?? "").toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.download, color: Colors.white),
            title: const Text("Télécharger la vidéo",
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _downloadVideo(videoUrl);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _downloadVideo(String url) async {
    try {
      setState(() {
        _downloading = true;
        _downloadProgress = 0.0;
      });

      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        Fluttertoast.showToast(msg: "Erreur téléchargement");
        setState(() => _downloading = false);
        return;
      }

      final contentLength = response.contentLength;
      int bytesDownloaded = 0;

      final dir = await getDownloadsDirectory();
      final file = File(
          "${dir!.path}/reel_${DateTime.now().millisecondsSinceEpoch}.mp4");

      final sink = file.openWrite();

      await for (final chunk in response) {
        bytesDownloaded += chunk.length;
        sink.add(chunk);

        if (contentLength > 0) {
          setState(() {
            _downloadProgress = (bytesDownloaded / contentLength) * 100;
          });
        }
      }

      await sink.close();

      Fluttertoast.showToast(msg: "Vidéo téléchargée !");
    } catch (e) {
      Fluttertoast.showToast(msg: "Erreur : $e");
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _downloadProgress = 0.0;
        });
      }
    }
  }

  // ============================================================
  // 💬 COMMENTAIRES (mode TikTok sur la même page)
  // ============================================================
  Future<void> _openCommentsOverlay(int index) async {
    await _currentPlayer?.pause();
    await WakelockPlus.disable();

    if (index < 0 || index >= _reels.length) return;
    final reel = _reels[index];
    final pubId = int.tryParse("${reel["id"]}") ?? 0;
    if (pubId == 0) return;

    setState(() {
      _showComments = true;
      _commentsPubId = pubId;
      _commentsReelIndex = index;
      _replyTo = null;
      _comments = [];
      _expandedComments.clear();
      _loadingComments = true;
    });

    try {
      final data = await apiFetchComments(pubId);
      if (!mounted) return;
      setState(() {
        _comments = data;
        _loadingComments = false;
      });
    } catch (e) {
      if (!mounted) return;
      _loadingComments = false;
      Fluttertoast.showToast(msg: "Erreur chargement commentaires");
      setState(() {});
    }
  }

  Future<void> _closeCommentsOverlay() async {
    setState(() {
      _showComments = false;
      _commentsPubId = null;
      _commentsReelIndex = null;
      _replyTo = null;
      _comments = [];
      _expandedComments.clear();
      _commentController.clear();
    });

    _commentFocusNode.unfocus();

    // 🔥 reprendre la vidéo + garder l’écran allumé
    if (_currentPlayer != null) {
      await _currentPlayer!.play();
      await WakelockPlus.enable();
    }
  }

  Future<void> _reloadComments() async {
    if (_commentsPubId == null) return;
    setState(() => _loadingComments = true);
    try {
      final data = await apiFetchComments(_commentsPubId!);
      if (!mounted) return;
      setState(() {
        _comments = data;
        _loadingComments = false;
      });
    } catch (e) {
      if (!mounted) return;
      _loadingComments = false;
      Fluttertoast.showToast(msg: "Erreur de rechargement");
      setState(() {});
    }
  }

  Future<void> _sendComment() async {
    if (_commentsPubId == null) return;
    final texte = _commentController.text.trim();
    if (texte.isEmpty) return;

    HapticFeedback.selectionClick();

    setState(() => _sendingComment = true);

    try {
      await apiAddComment(
        publicationId: _commentsPubId!,
        texte: texte,
        parentId: _replyTo,
      );

      _commentController.clear();
      _replyTo = null;
      _commentFocusNode.unfocus();

      await _reloadComments();

      // MAJ compteur sur le reel courant
      if (_commentsReelIndex != null &&
          _commentsReelIndex! >= 0 &&
          _commentsReelIndex! < _reels.length) {
        final total = _countCommentsTree(_comments);
        setState(() {
          _reels[_commentsReelIndex!]["comments"] = total;
        });
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Erreur : $e");
    } finally {
      if (mounted) {
        setState(() => _sendingComment = false);
      }
    }
  }

  int _countCommentsTree(List<dynamic> list) {
    int total = 0;
    for (final c in list) {
      total++;
      final replies = (c["replies"] ?? []) as List;
      total += replies.length;
    }
    return total;
  }

  // ==========================
  // ⏱️ Temps relatif
  // ==========================
  String _timeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "";
    final date = DateTime.tryParse(dateStr);
    if (date == null) return "";
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return "à l’instant";
    if (diff.inMinutes < 60) return "il y a ${diff.inMinutes} min";
    if (diff.inHours < 24) return "il y a ${diff.inHours} h";
    if (diff.inDays < 7) return "il y a ${diff.inDays} j";
    return "il y a ${diff.inDays ~/ 7} sem";
  }

  String _formatCount(int n) {
    if (n >= 1000000) {
      final v = n / 1000000.0;
      if (v == v.floorToDouble()) return "${v.toInt()}M";
      return "${v.toStringAsFixed(1)}M";
    } else if (n >= 1000) {
      final v = n / 1000.0;
      if (v == v.floorToDouble()) return "${v.toInt()}k";
      return "${v.toStringAsFixed(1)}k";
    }
    return n.toString();
  }

  String _buildName(Map<String, dynamic> c) {
    final type = (c['type_compte'] ?? 'personnel').toString();
    if (type == 'professionnel') return c['nom'] ?? 'Utilisateur';

    final prenom = c['prenom'] ?? '';
    final postnom = c['postnom'] ?? '';
    final nom = c['nom'] ?? '';

    final full = [prenom, postnom, nom]
        .where((e) => e.toString().trim().isNotEmpty)
        .join(' ')
        .trim();

    return full.isEmpty ? 'Utilisateur' : full;
  }

  String _buildPhoto(String? url) {
    if (url == null || url.isEmpty) {
      return 'https://zuachat.com/assets/default-avatar.png';
    }
    if (url.startsWith('http')) return url;
    return 'https://zuachat.com/$url';
  }

  Map<String, int> _getReactions(dynamic c) {
    final raw = c['reactions'] ?? c['reactions_counts'];
    final Map<String, int> result = {};

    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is int) {
          result[key.toString()] = value;
        } else {
          final parsed = int.tryParse(value.toString());
          if (parsed != null) {
            result[key.toString()] = parsed;
          }
        }
      });
    }

    return result;
  }

  Widget _videoProgressBar() {
    if (_videoDuration.inMilliseconds <= 0) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {}, // empêche le tap de passer à la vidéo
          onHorizontalDragStart: (_) {}, // empêche pause/play
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25), // 🔥 contraste léger
              borderRadius: BorderRadius.circular(20),
            ),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.5, // 🔥 plus visible
                activeTrackColor: Colors.redAccent.withOpacity(0.95),
                inactiveTrackColor:
                    Colors.white.withOpacity(0.45), // 🔥 éclairci
                thumbColor: Colors.redAccent,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7, // 🔥 thumb plus visible
                ),
                overlayColor: Colors.redAccent.withOpacity(0.25),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 14,
                ),
              ),
              child: Slider(
                min: 0,
                max: _videoDuration.inMilliseconds.toDouble(),
                value: _currentPosition.inMilliseconds
                    .clamp(0, _videoDuration.inMilliseconds)
                    .toDouble(),
                onChangeStart: (_) {
                  _isDraggingSlider = true;
                },
                onChanged: (value) {
                  setState(() {
                    _currentPosition = Duration(milliseconds: value.toInt());
                  });
                },
                onChangeEnd: (value) async {
                  await _currentPlayer
                      ?.seekTo(Duration(milliseconds: value.toInt()));
                  _isDraggingSlider = false;
                },
              ),
            ),
          ),
        ),

        // ⏱️ temps courant / durée
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_currentPosition),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                _formatDuration(_videoDuration),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReactionsBubble(dynamic c) {
    final reactions = _getReactions(c);
    if (reactions.isEmpty) return const SizedBox.shrink();

    final emojis = ['❤️', '👍', '😂', '😮'];
    final List<Widget> chips = [];

    for (final emoji in emojis) {
      final count = reactions[emoji] ?? 0;
      if (count > 0) {
        chips.add(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 2),
            Text(
              _formatCount(count),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ));
      }
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 4, right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: chips,
        ),
      ),
    );
  }

  // ==============================
  // 💬 UI Commentaire & Réponse
  // ==============================
  Widget _buildComment(dynamic c, int index) {
    final replies = (c['replies'] ?? []) as List;
    final verified = c['badge_verified'] == 1;
    final photo = _buildPhoto(c['photo']);
    final isOwner = _userId != null && c['user_id'] == _userId;
    final nomAuteur = _buildName(c);

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + (index * 30)),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onLongPress: () => _showCommentOptions(c, isOwner),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: CachedNetworkImageProvider(photo),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Flexible(
                                    child: Text(
                                      nomAuteur,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  VerifiedBadge.mini(isVerified: verified),
                                ]),
                                const SizedBox(height: 2),
                                Text(
                                  c['texte'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ]),
                        ),
                        _buildReactionsBubble(c),
                        const SizedBox(height: 2),
                        Row(children: [
                          TextButton(
                            onPressed: () {
                              setState(() => _replyTo = c['id']);
                              Future.delayed(const Duration(milliseconds: 100),
                                  () {
                                FocusScope.of(context)
                                    .requestFocus(_commentFocusNode);
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                            ),
                            child: const Text(
                              "Répondre",
                              style: TextStyle(
                                  fontSize: 12, color: Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _timeAgo(c['created_at']),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white54),
                          ),
                        ]),
                      ]),
                ),
              ]),
              if (replies.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 45, top: 3),
                  child: !_expandedComments.contains(c['id'])
                      ? TextButton(
                          onPressed: () =>
                              setState(() => _expandedComments.add(c['id'])),
                          child: Text(
                            "Afficher les réponses (${replies.length})",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextButton(
                              onPressed: () => setState(
                                  () => _expandedComments.remove(c['id'])),
                              child: const Text(
                                "Masquer les réponses",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            ...replies.map((r) => _buildReply(r, c)).toList(),
                          ],
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReply(dynamic r, dynamic parent) {
    final verified = r['badge_verified'] == 1;
    final photo = _buildPhoto(r['photo']);
    final isOwner = _userId != null && r['user_id'] == _userId;
    final nomAuteur = _buildName(r);

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 15),
          child: child,
        ),
      ),
      child: GestureDetector(
        onLongPress: () => _showCommentOptions(r, isOwner),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 36),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: CachedNetworkImageProvider(photo),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(
                          nomAuteur,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      VerifiedBadge.mini(isVerified: verified),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      r['texte'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    _buildReactionsBubble(r),
                    const SizedBox(height: 2),
                    Row(children: [
                      TextButton(
                        onPressed: () {
                          setState(() => _replyTo = parent['id']);
                          _commentController.clear();
                          Future.delayed(const Duration(milliseconds: 100), () {
                            FocusScope.of(context)
                                .requestFocus(_commentFocusNode);
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                        ),
                        child: const Text(
                          "Répondre",
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _timeAgo(r['created_at']),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ==============================
  // ⚙️ Options commenter (réactions + edit/suppr)
  // ==============================
  void _showCommentOptions(dynamic c, bool isOwner) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ❤️ Barre des réactions
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var emoji in ['❤️', '👍', '😂', '😮'])
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        HapticFeedback.selectionClick();
                        try {
                          final res = await apiReactToComment(
                            commentId: c['id'],
                            emoji: emoji,
                          );
                          Fluttertoast.showToast(
                            msg: res['message'] ?? "Réaction enregistrée",
                          );
                          _reloadComments();
                        } catch (e) {
                          Fluttertoast.showToast(msg: e.toString());
                        }
                      },
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: const Icon(Icons.reply, color: Colors.white70),
              title: const Text(
                'Répondre',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyTo = c['id']);
                FocusScope.of(context).requestFocus(_commentFocusNode);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white70),
              title: const Text(
                'Copier le texte',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Clipboard.setData(
                  ClipboardData(text: c['texte'] ?? ''),
                );
                Navigator.pop(context);
                Fluttertoast.showToast(msg: "Commentaire copié !");
              },
            ),
            if (isOwner) ...[
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text(
                  'Modifier',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _editComment(c);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteComment(c['id']);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editComment(dynamic c) async {
    final ctrl = TextEditingController(text: c['texte']);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text("Modifier le commentaire",
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          maxLines: null,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "Nouveau texte...",
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );

    if (newText != null && newText.isNotEmpty) {
      try {
        final res = await apiEditComment(
          commentId: c['id'],
          texte: newText,
        );
        Fluttertoast.showToast(msg: res['message']);
        await _reloadComments();
      } catch (e) {
        Fluttertoast.showToast(msg: e.toString());
      }
    }
  }

  Future<void> _deleteComment(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text("Supprimer ?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Voulez-vous supprimer ce commentaire ?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Supprimer",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await apiDeleteComment(id);
        Fluttertoast.showToast(msg: res['message']);
        await _reloadComments();
      } catch (e) {
        Fluttertoast.showToast(msg: e.toString());
      }
    }
  }

  // ============================================================
  // 🔥 UI PRINCIPALE
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: ZuaLoaderMini(size: 30),
        ),
      );
    }

    /// 🟩🟩 AJOUTE CE BLOC EXACTEMENT ICI 🟩🟩
    if (!_loading && !_error && _reels.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            "Aucun reel pour le moment",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false, // 🔥 AJOUT OBLIGATOIRE ICI
      body: Stack(
        children: [
          // =======================
          // 🎥 PageView Reels
          // =======================
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _reels.length,
            onPageChanged: (index) {
              if (_currentIndex == index) return;

              _currentIndex = index;
              _playReel(index);

              if (index >= _reels.length - 2) {
                _loadMore();
              }
            },
            itemBuilder: (context, index) {
              final reel = _reels[index];
              final id = int.tryParse("${reel["id"]}") ?? 0;
              final isCurrent = _currentReelId == reel["id"];

              final auteur = (reel["auteur"] ?? {}) as Map<String, dynamic>;
              final username = (auteur["username"] ?? "").toString();
              final fullName = (auteur["nom"] ?? username).toString().trim();
              final isVerified = (auteur["badge_verified"] == 1 ||
                  auteur["badge_verified"] == '1');
              final avatarUrl = (auteur["photo"] ?? "").toString().trim();

              final texte = (reel["texte"] ?? "").toString();
              final likes = int.tryParse("${reel["likes"] ?? 0}") ?? 0;
              final comments = int.tryParse("${reel["comments"] ?? 0}") ?? 0;
              final liked = reel["liked"] == true;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  if (_isDraggingSlider) return; // 🔥 AJOUT ICI

                  if (_currentPlayer == null) return;

                  if (_currentPlayer!.value.isPlaying) {
                    await _currentPlayer!.pause();
                    await WakelockPlus.disable();
                  } else {
                    await _currentPlayer!.play();
                    await WakelockPlus.enable();
                  }

                  setState(() {});
                },

                onDoubleTap: () => _toggleLike(index),
                onLongPress: () => _openReelOptions(index), // 🔥 AJOUT

                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // VIDEO
                    if (isCurrent &&
                        _currentPlayer != null &&
                        _currentPlayer!.value.isInitialized)
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _currentPlayer!.value.size.width,
                          height: _currentPlayer!.value.size.height,
                          child: VideoPlayer(_currentPlayer!),
                        ),
                      )
                    else
                      CachedNetworkImage(
                        imageUrl: reel["thumbnail"] ?? "",
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        placeholder: (_, __) =>
                            const Center(child: ZuaLoaderMini(size: 30)),
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(Icons.play_circle,
                              color: Colors.white70, size: 60),
                        ),
                      ),
// 🎬 BARRE DE PROGRESSION VIDEO
                    if (isCurrent &&
                        _currentPlayer != null &&
                        _currentPlayer!.value.isInitialized)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SafeArea(
                          top: false,
                          child: Container(
                            padding: const EdgeInsets.only(bottom: 6),
                            color: Colors.transparent,
                            child: IgnorePointer(
                              ignoring: false,
                              child: _videoProgressBar(),
                            ),
                          ),
                        ),
                      ),

                    // Dégradé bas
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        ignoring: true,
                        child: Container(
                          height: 260,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black87,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Boutons droite (avatar + like + com + son)
                    Positioned(
                      right: 16,
                      bottom: 80,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Avatar
                          GestureDetector(
                            onTap: () => _openProfile(auteur),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundImage: avatarUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(avatarUrl)
                                  : const AssetImage(
                                          'assets/default-avatar.png')
                                      as ImageProvider,
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Like
                          GestureDetector(
                            onTap: () => _toggleLike(index),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.favorite,
                                  size: 40,
                                  color:
                                      liked ? Colors.redAccent : Colors.white,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatCount(likes),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Commentaires
                          GestureDetector(
                            onTap: () => _openCommentsOverlay(index),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.comment,
                                  size: 40,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatCount(comments),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 👁️ VUES
                          const SizedBox(height: 18),
                          Column(
                            children: [
                              const Icon(
                                Icons.remove_red_eye,
                                size: 36,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatCount(
                                  int.tryParse("${reel["views"] ?? 0}") ?? 0,
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // Son
                          GestureDetector(
                            onTap: _toggleSound,
                            child: Column(
                              children: [
                                Icon(
                                  _soundOn ? Icons.volume_up : Icons.volume_off,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Infos auteur + texte
                    Positioned(
                      left: 16,
                      bottom: 90,
                      right: 110,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => _openProfile(auteur),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                VerifiedBadge.mini(isVerified: isVerified),
                                const SizedBox(width: 6),
                                Text(
                                  "• ${_timeAgo(reel['created_at'])}",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          GestureDetector(
                            onTap: () => _openProfile(auteur),
                            child: Text(
                              "@$username",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (texte.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                texte,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Petit texte "Reels" en haut
          const Positioned(
            top: 40,
            left: 16,
            child: Text(
              "Zua Reels",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // =======================
          // 💬 OVERLAY COMMENTAIRES
          // =======================
          if (_showComments && _commentsPubId != null)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus(); // 🔥 ferme le clavier
                },
                behavior: HitTestBehavior.deferToChild,
                child: Container(
                  color: Colors.black.withOpacity(0.20),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      height: MediaQuery.of(context).size.height * 0.6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF000000),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 6),
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              children: [
                                const Text(
                                  "Commentaires",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.white),
                                  onPressed: _closeCommentsOverlay,
                                ),
                              ],
                            ),
                          ),
                          const Divider(
                            color: Colors.white24,
                            height: 1,
                          ),
                          Expanded(
                            child: _loadingComments
                                ? const Center(
                                    child: ZuaLoaderMini(size: 26),
                                  )
                                : _comments.isEmpty
                                    ? const Center(
                                        child: Text(
                                          "Aucun commentaire pour le moment",
                                          style: TextStyle(
                                            color: Colors.white54,
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.only(
                                          top: 6,
                                          bottom: 10,
                                        ),
                                        itemCount: _comments.length,
                                        itemBuilder: (context, index) {
                                          final c = _comments[index];
                                          return _buildComment(c, index);
                                        },
                                      ),
                          ),

                          // Champ de saisie commentaire
                          AnimatedPadding(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context)
                                  .viewInsets
                                  .bottom, // 🔥 CLAVIER
                            ),
                            child: SafeArea(
                              top: false,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF000000),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: 4,
                                      offset: const Offset(0, -2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _commentController,
                                        focusNode: _commentFocusNode,
                                        style: const TextStyle(
                                            color: Colors.white),
                                        textInputAction: TextInputAction.send,
                                        maxLines: 3,
                                        minLines: 1,
                                        onSubmitted: (_) => _sendComment(),
                                        decoration: InputDecoration(
                                          hintText: _replyTo == null
                                              ? "Écrire un commentaire..."
                                              : "Répondre à un commentaire...",
                                          hintStyle: const TextStyle(
                                              color: Colors.white54),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(25),
                                            borderSide: const BorderSide(
                                                color: Colors.white24,
                                                width: 0.8),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 6,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _sendingComment
                                        ? const Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: ZuaLoaderMini(size: 22),
                                          )
                                        : IconButton(
                                            icon: const Icon(Icons.send,
                                                color: Colors.white),
                                            onPressed: _sendComment,
                                          ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // =======================
// 🔥 OVERLAY TÉLÉCHARGEMENT
// =======================
          if (_downloading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ZuaLoaderMini(size: 40),
                      const SizedBox(height: 16),
                      Text(
                        "Téléchargement...",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${_downloadProgress.toStringAsFixed(0)} %",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
