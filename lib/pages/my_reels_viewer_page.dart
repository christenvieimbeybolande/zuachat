import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/comments.dart';
import '../api/react_comment.dart';

import '../widgets/zua_loader_mini.dart';
import '../widgets/verified_badge.dart';

import '../api/api_add_reel_view.dart';
import '../api/api_delete_reel.dart';
import '../api/react_publication.dart';

class MyReelsViewerPage extends StatefulWidget {
  final List<Map<String, dynamic>> reels;
  final int initialIndex;

  const MyReelsViewerPage({
    super.key,
    required this.reels,
    required this.initialIndex,
  });

  @override
  State<MyReelsViewerPage> createState() => _MyReelsViewerPageState();
}

class _MyReelsViewerPageState extends State<MyReelsViewerPage> {
  final PageController _pageController = PageController();

  VideoPlayerController? _currentPlayer;
  VideoPlayerController? _preloadPlayer;
  int? _preloadIndex;
  int? _currentReelId;

  final Set<int> _viewed = {};

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  int _countCommentsTree(List<dynamic> list) {
    int total = 0;
    for (final c in list) {
      total++;
      final replies = (c["replies"] ?? []) as List;
      if (replies.isNotEmpty) {
        total += _countCommentsTree(replies);
      }
    }
    return total;
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
      final v = n / 1000000;
      return v == v.floorToDouble()
          ? "${v.toInt()}M"
          : "${v.toStringAsFixed(1)}M";
    }
    if (n >= 1000) {
      final v = n / 1000;
      return v == v.floorToDouble()
          ? "${v.toInt()}k"
          : "${v.toStringAsFixed(1)}k";
    }
    return n.toString();
  }

  int _currentIndex = 0;
  bool _soundOn = true;

  Duration _currentPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;
  bool _isDragging = false;

  bool _downloading = false;
  double _downloadProgress = 0;

// =======================
// 💬 Etat des commentaires (ALIGNÉ AVEC ReelsPage)
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

// 🔥 utilisé par la vidéo + commentaires (UNE SEULE FOIS)
  VoidCallback? _videoListener;

  int? _userId;

  Future<void> _loadMyId() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = int.tryParse(prefs.getString('user_id') ?? '');
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadMyId(); // 🔥 AJOUT ICI

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _pageController.jumpToPage(_currentIndex);
      await _playReel(_currentIndex);
    });
  }

  @override
  void dispose() {
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

  // ===========================================================
  // 🎥 PLAY REEL (COPIE DE ReelsPage)
  // ===========================================================
  Future<void> _playReel(int index) async {
    if (index < 0 || index >= widget.reels.length) return;

    final reel = widget.reels[index];
    final reelId = int.tryParse("${reel['id']}") ?? 0;
    final url = reel['video']?.toString() ?? "";
    if (url.isEmpty) return;

    if (_currentReelId == reelId) return;

    await WakelockPlus.disable();

    if (_videoListener != null && _currentPlayer != null) {
      _currentPlayer!.removeListener(_videoListener!);
    }

    _currentPlayer?.pause();
    _currentPlayer?.dispose();

    if (_preloadIndex == index && _preloadPlayer != null) {
      _currentPlayer = _preloadPlayer;
      _preloadPlayer = null;
      _preloadIndex = null;
    } else {
      _currentPlayer = VideoPlayerController.networkUrl(Uri.parse(url));
      await _currentPlayer!.initialize();
    }

    _videoDuration = _currentPlayer!.value.duration;
    _currentPosition = Duration.zero;

    _videoListener = () {
      if (!mounted || _isDragging) return;
      final v = _currentPlayer!.value;
      if (!v.isInitialized) return;
      setState(() => _currentPosition = v.position);
    };

    _currentPlayer!.addListener(_videoListener!);
    _currentPlayer!.setLooping(true);
    _currentPlayer!.setVolume(_soundOn ? 1.0 : 0.0);
    _isDragging = false;

    await _currentPlayer!.play();
    await WakelockPlus.enable();

    setState(() => _currentReelId = reelId);

    if (reelId > 0 && !_viewed.contains(reelId)) {
      _viewed.add(reelId);
      Future.delayed(const Duration(milliseconds: 1500), () async {
        if (!mounted || _currentIndex != index) return;
        await apiAddReelView(reelId);
        setState(() {
          reel['views'] = (int.tryParse("${reel['views'] ?? 0}") ?? 0) + 1;
        });
      });
    }

    _preloadNext(index);
  }

  Future<void> _preloadNext(int index) async {
    final next = index + 1;
    if (next >= widget.reels.length) return;

    final url = widget.reels[next]['video']?.toString() ?? "";
    if (url.isEmpty) return;

    try {
      _preloadPlayer?.dispose();
      _preloadPlayer = VideoPlayerController.networkUrl(Uri.parse(url));
      await _preloadPlayer!.initialize();
      _preloadPlayer!.setVolume(0);
      _preloadIndex = next;
    } catch (_) {}
  }

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

  // ===========================================================
  // 🎬 BARRE DE PROGRESSION (CLAIRE)
  // ===========================================================
  Widget _videoProgressBar() {
    if (_videoDuration.inMilliseconds <= 0) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.5,
              activeTrackColor: Colors.redAccent.withOpacity(0.95),
              inactiveTrackColor: Colors.white.withOpacity(0.45),
              thumbColor: Colors.redAccent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              min: 0,
              max: _videoDuration.inMilliseconds.toDouble(),
              value: _currentPosition.inMilliseconds
                  .clamp(0, _videoDuration.inMilliseconds)
                  .toDouble(),
              onChangeStart: (_) => _isDragging = true,
              onChanged: (v) {
                setState(() {
                  _currentPosition = Duration(milliseconds: v.toInt());
                });
              },
              onChangeEnd: (v) async {
                await _currentPlayer?.seekTo(Duration(milliseconds: v.toInt()));
                _isDragging = false;
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_currentPosition),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                _formatDuration(_videoDuration),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

// ============================================================
// 💬 COMMENTAIRES (VERSION REELSPAGE)
// ============================================================

  Future<void> _openCommentsOverlay(int index) async {
    await _currentPlayer?.pause();
    await WakelockPlus.disable();

    if (index < 0 || index >= widget.reels.length) return;
    final reel = widget.reels[index];
    final pubId = int.tryParse("${reel['id']}") ?? 0;
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
    } catch (_) {
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
    } catch (_) {
      if (!mounted) return;
      _loadingComments = false;
      Fluttertoast.showToast(msg: "Erreur rechargement");
      setState(() {});
    }
  }

  Future<void> _sendComment() async {
    if (_commentsPubId == null) return;
    final txt = _commentController.text.trim();
    if (txt.isEmpty) return;

    HapticFeedback.selectionClick();

    setState(() => _sendingComment = true);

    try {
      await apiAddComment(
        publicationId: _commentsPubId!,
        texte: txt,
        parentId: _replyTo,
      );

      _commentController.clear();
      _replyTo = null;
      _commentFocusNode.unfocus();

      await _reloadComments();

      if (_commentsReelIndex != null &&
          _commentsReelIndex! >= 0 &&
          _commentsReelIndex! < widget.reels.length) {
        final total = _countCommentsTree(_comments);
        setState(() {
          widget.reels[_commentsReelIndex!]['comments'] = total;
        });
      }
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  // ===========================================================
  // 🖥️ UI
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.reels.length,
            onPageChanged: (i) {
              _currentIndex = i;
              _playReel(i);
            },
            itemBuilder: (_, index) {
              final reel = widget.reels[index];
              final isCurrent = _currentReelId == reel['id'];

              final auteur = (reel['auteur'] ?? {}) as Map<String, dynamic>;
              final name = auteur['nom'] ?? 'Moi';
              final verified = auteur['badge_verified'] == 1;
              final likes = int.tryParse("${reel['likes'] ?? 0}") ?? 0;
              final views = int.tryParse("${reel['views'] ?? 0}") ?? 0;
              final liked = reel['liked'] == true;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  if (_isDragging || _currentPlayer == null) return;

                  if (_currentPlayer!.value.isPlaying) {
                    await _currentPlayer!.pause();
                    await WakelockPlus.disable();
                  } else {
                    await _currentPlayer!.play();
                    await WakelockPlus.enable();
                  }
                },
                onDoubleTap: () async {
                  final res = await apiReactToPublication(
                    publicationId: reel['id'],
                    emoji: "❤️",
                  );
                  setState(() {
                    reel['liked'] = !res['removed'];
                    reel['likes'] = res['count'];
                  });
                },
                onLongPress: () => _openReelOptions(index),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ======================
                    // 🎥 VIDEO
                    // ======================
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
                        imageUrl: reel['thumbnail'] ?? "",
                        fit: BoxFit.cover,
                      ),

                    // ======================
                    // 🎬 BARRE DE LECTURE
                    // ======================
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SafeArea(
                        top: false,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (_) => true,
                          child: _videoProgressBar(),
                        ),
                      ),
                    ),

                    // ======================
                    // 🌑 DÉGRADÉ NOIR BAS
                    // ======================
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

                    // ======================
                    // 👉 BOUTONS DROITE
                    // ======================
                    Positioned(
                      right: 16,
                      bottom: 80,
                      child: Column(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 22,
                            backgroundImage: (auteur['photo'] ?? '')
                                    .toString()
                                    .isNotEmpty
                                ? CachedNetworkImageProvider(auteur['photo'])
                                : const AssetImage('assets/default-avatar.png')
                                    as ImageProvider,
                          ),

                          const SizedBox(height: 18),

                          // Like
                          GestureDetector(
                            onTap: () async {
                              final res = await apiReactToPublication(
                                publicationId: reel['id'],
                                emoji: "❤️",
                              );
                              setState(() {
                                reel['liked'] = !res['removed'];
                                reel['likes'] = res['count'];
                              });
                            },
                            child: Column(
                              children: [
                                Icon(
                                  Icons.favorite,
                                  size: 40,
                                  color:
                                      liked ? Colors.redAccent : Colors.white,
                                ),
                                Text(
                                  _formatCount(likes),
                                  style: const TextStyle(color: Colors.white),
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
                                Text(
                                  _formatCount(
                                    int.tryParse("${reel['comments'] ?? 0}") ??
                                        0,
                                  ),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Son
                          GestureDetector(
                            onTap: () {
                              _soundOn = !_soundOn;
                              _currentPlayer?.setVolume(_soundOn ? 1 : 0);
                              setState(() {});
                            },
                            child: Icon(
                              _soundOn ? Icons.volume_up : Icons.volume_off,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ======================
                    // 🧾 TEXTE + AUTEUR
                    // ======================
                    Positioned(
                      left: 16,
                      bottom: 90,
                      right: 110,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 4),
                              VerifiedBadge.mini(isVerified: verified),
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
                          const SizedBox(height: 8),
                          if ((reel['texte'] ?? '').toString().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                reel['texte'],
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

          // =======================
// 💬 OVERLAY COMMENTAIRES
// =======================
          if (_showComments && _commentsPubId != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.20),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.6,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(22)),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const SizedBox(width: 16),
                            const Text(
                              "Commentaires",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon:
                                  const Icon(Icons.close, color: Colors.white),
                              onPressed: _closeCommentsOverlay,
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white24),
                        Expanded(
                          child: _loadingComments
                              ? const Center(child: ZuaLoaderMini(size: 26))
                              : _comments.isEmpty
                                  ? const Center(
                                      child: Text(
                                        "Aucun commentaire pour le moment",
                                        style: TextStyle(color: Colors.white54),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.only(
                                          top: 6, bottom: 10),
                                      itemCount: _comments.length,
                                      itemBuilder: (context, index) {
                                        final c = _comments[index];
                                        return _buildComment(c, index);
                                      },
                                    ),
                        ),
                        AnimatedPadding(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: SafeArea(
                            top: false,
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _commentController,
                                    focusNode: _commentFocusNode,
                                    style: const TextStyle(color: Colors.white),
                                    maxLines: null, // 🔥 IMPORTANT
                                    keyboardType: TextInputType.multiline,
                                    decoration: const InputDecoration(
                                      hintText: "Écrire un commentaire...",
                                      hintStyle:
                                          TextStyle(color: Colors.white54),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                _sendingComment
                                    ? const Padding(
                                        padding: EdgeInsets.all(8),
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
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_downloading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ZuaLoaderMini(size: 40),
                      const SizedBox(height: 8),
                      Text(
                        "${_downloadProgress.toStringAsFixed(0)} %",
                        style: const TextStyle(color: Colors.white),
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

  // ===========================================================
  // ⚙️ OPTIONS
  // ===========================================================
  void _openReelOptions(int index) {
    final reel = widget.reels[index];
    final url = reel['video']?.toString() ?? "";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.download, color: Colors.white),
            title: const Text("Télécharger",
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _downloadVideo(url);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text("Supprimer", style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
              await apiDeleteReel(reel['id']);
              Navigator.pop(context, true);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _downloadVideo(String url) async {
    try {
      setState(() {
        _downloading = true;
        _downloadProgress = 0;
      });

      final req = await HttpClient().getUrl(Uri.parse(url));
      final res = await req.close();

      final total = res.contentLength;
      int received = 0;

      final dir = await getDownloadsDirectory();
      final file = File(
          "${dir!.path}/reel_${DateTime.now().millisecondsSinceEpoch}.mp4");
      final sink = file.openWrite();

      await for (final chunk in res) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) {
          setState(() => _downloadProgress = (received / total) * 100);
        }
      }

      await sink.close();
      Fluttertoast.showToast(msg: "Téléchargé");
    } catch (_) {
      Fluttertoast.showToast(msg: "Erreur téléchargement");
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _downloadProgress = 0;
        });
      }
    }
  }
}
