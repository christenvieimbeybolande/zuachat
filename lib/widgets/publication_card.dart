// publication_card.dart (VERSION ULTRA-PRO : séparation UI / state, keep-alive, performances)
import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart'; // POUR Copier le texte

import '../pages/comments_page.dart';
import '../pages/profile_page.dart';
import '../pages/reactions_page.dart';
import '../pages/user_profile.dart';
import '../widgets/image_preview_dialog.dart';
import '../widgets/save_to_folder_dialog.dart';
import '../widgets/verified_badge.dart';
import '../api/client.dart';
import '../api/api_get_reactions.dart';
import '../api/mask_publication.dart';
import '../api/react_publication.dart';
import '../pages/share_publication_page.dart';

/// Parent (stateless) — pure UI wrapper + stable key
/// Inner (_PublicationCardInner) — stateful, keepAlive, handles animations & network
class PublicationCard extends StatelessWidget {
  final Map<String, dynamic> publication;
  final Future<Dio> Function() authedDio;
  final VoidCallback? onRefresh;
  final bool showMenu;
  final bool isFromProfile;
  final bool isSavedFolder;
  final VoidCallback? onLikeNetworkStart;
  final void Function(bool removed)? onLikeNetworkDone;

  const PublicationCard({
    super.key,
    required this.publication,
    required this.authedDio,
    this.onRefresh,
    this.showMenu = true,
    this.isFromProfile = false,
    this.isSavedFolder = false,
    this.onLikeNetworkStart,
    this.onLikeNetworkDone,
  });

  @override
  Widget build(BuildContext context) {
    // Use a stable PageStorageKey-like key based on publication id to help Flutter preserve state
    final id = publication['id']?.toString() ?? UniqueKey().toString();

    return Container(
      key: ValueKey('pub_card_$id'),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      child: _PublicationCardInner(
        publication: publication,
        authedDio: authedDio,
        onRefresh: onRefresh,
        showMenu: showMenu,
        isFromProfile: isFromProfile,
        isSavedFolder: isSavedFolder,
        onLikeNetworkStart: onLikeNetworkStart,
        onLikeNetworkDone: onLikeNetworkDone,
      ),
    );
  }
}

/// Inner widget which actually holds the state (kept alive)
class _PublicationCardInner extends StatefulWidget {
  final Map<String, dynamic> publication;
  final Future<Dio> Function() authedDio;
  final VoidCallback? onRefresh;
  final bool showMenu;
  final bool isFromProfile;
  final bool isSavedFolder;
  final VoidCallback? onLikeNetworkStart;
  final void Function(bool removed)? onLikeNetworkDone;

  const _PublicationCardInner({
    required this.publication,
    required this.authedDio,
    this.onRefresh,
    this.showMenu = true,
    this.isFromProfile = false,
    this.isSavedFolder = false,
    this.onLikeNetworkStart,
    this.onLikeNetworkDone,
  });

  @override
  State<_PublicationCardInner> createState() => _PublicationCardInnerState();
}

class _PublicationCardInnerState extends State<_PublicationCardInner>
    with AutomaticKeepAliveClientMixin {
  // Keep-alive to avoid disposal when off-screen (helps preserve card local state)
  @override
  bool get wantKeepAlive => true;

  // Lightweight local UI state (only what's necessary)
  late bool liked;
  String? myEmoji;
  late int likeCount;
  late int commentCount;
  late int shareCount;
  bool userCommented = false;
  int? _myId;

  // Lightweight implicit animation flag (avoid AnimationController per card)
  bool _likeAnimating = false;

  // Immutable snapshot of publication used for display (so rebuilds from parent affect less)
  late final Map<String, dynamic> _pubSnapshot;
  late final Map<String, dynamic> _auteurSnapshot;

  @override
  void initState() {
    super.initState();

    // Create a shallow copy snapshot to minimise future map mutations causing rebuild surprises
    _pubSnapshot = Map<String, dynamic>.from(widget.publication);
    _auteurSnapshot = Map<String, dynamic>.from(
        (_pubSnapshot['auteur'] ?? <String, dynamic>{}) as Map);

    likeCount = int.tryParse('${_pubSnapshot['likes'] ?? 0}') ?? 0;
    commentCount = int.tryParse('${_pubSnapshot['comments'] ?? 0}') ?? 0;
    shareCount = int.tryParse('${_pubSnapshot['shares'] ?? 0}') ?? 0;

    liked = (_pubSnapshot['liked'] == true ||
        _pubSnapshot['liked'] == 1 ||
        _pubSnapshot['is_liked'] == true);

    var m = _pubSnapshot['my_emoji'];
    if (m == false || m == 'false') m = null;
    if (m != null && m.toString().isNotEmpty) {
      liked = true;
      myEmoji = m.toString();
    }

    userCommented = (_pubSnapshot['user_commented'] == true ||
        _pubSnapshot['has_commented'] == 1);

    _loadMyIdSilently();
  }

  Future<void> _loadMyIdSilently() async {
    final prefs = await SharedPreferences.getInstance();
    final idStr = prefs.getString('user_id') ?? '';
    if (!mounted) return;
    setState(() {
      _myId = int.tryParse(idStr) ?? 0;
    });
  }

  // ---------- HELPERS ----------
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

  int _extractUserId(Map<String, dynamic> pub) {
    final auteur = pub['auteur'] ?? {};
    dynamic id =
        auteur['id'] ?? pub['user_id'] ?? pub['auteur_id'] ?? pub['owner_id'];
    if (id == null && pub['user'] is Map) id = pub['user']['id'];
    if (id is String) return int.tryParse(id) ?? 0;
    if (id is int) return id;
    return 0;
  }

  void _openProfile(BuildContext context, int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final myId = int.tryParse(prefs.getString('user_id') ?? '0') ?? 0;
    if (myId == userId) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const ProfilePage()));
    } else {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => UserProfilePage(userId: userId)));
    }
  }

  Future<void> _openReactionsPage() async {
    final res = await apiGetPublicationReactions(_pubSnapshot['id']);
    if (!res['success']) {
      Fluttertoast.showToast(msg: "Erreur chargement réactions");
      return;
    }
    final users = List<Map<String, dynamic>>.from(res['users'] ?? []);
    final cnt = res['count'] ?? likeCount;

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReactionsPage(
          publicationId: _pubSnapshot['id'],
          totalCount: cnt,
          users: users,
          reactionSummary: res['summary'], // 🔥 AJOUT
        ),
      ),
    );
  }

  Future<void> _deletePublication() async {
    try {
      final dio = await widget.authedDio();
      final res = await dio.post(
        'https://zuachat.com/api/delete_publication.php',
        data: {'id': _pubSnapshot['id']},
      );
      if (res.data['success'] == true) {
        Fluttertoast.showToast(msg: "🗑 Publication supprimée !");
        widget.onRefresh?.call();
      } else {
        Fluttertoast.showToast(
            msg: res.data['message'] ?? 'Erreur suppression',
            backgroundColor: Colors.red);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Erreur : $e", backgroundColor: Colors.red);
    }
  }

  Future<void> _maskPublication() async {
    final res = await maskPublication(_pubSnapshot['id']);
    if (res['success'] == true) {
      Fluttertoast.showToast(msg: "👁 Publication masquée");
      widget.onRefresh?.call();
    } else {
      Fluttertoast.showToast(
          msg: res['message'] ?? "Erreur de masquage",
          backgroundColor: Colors.red);
    }
  }

  Future<void> _removeFromFolder() async {
    try {
      final dio = await widget.authedDio();
      final res = await dio.post(
        '/remove_saved_publication.php',
        data: {
          'publication_id': _pubSnapshot['id'],
          'folder_id': _pubSnapshot['dossier_id']
        },
      );
      if (res.data['success'] == true) {
        Fluttertoast.showToast(
            msg: "Retirée du dossier ✔", backgroundColor: Colors.green);
        widget.onRefresh?.call();
      } else {
        Fluttertoast.showToast(
            msg: res.data['message'] ?? "Erreur", backgroundColor: Colors.red);
      }
    } catch (e) {
      Fluttertoast.showToast(
          msg: "Erreur réseau : $e", backgroundColor: Colors.red);
    }
  }

  // ---------- LIKES / RÉACTIONS (isolated & resilient) ----------
  bool _reacting = false;

  Future<void> _toggleReaction(String emoji) async {
    if (_reacting) return;
    _reacting = true;

    try {
      widget.onLikeNetworkStart?.call();
      setState(() => _likeAnimating = true);

      final res = await apiReactToPublication(
          publicationId: _pubSnapshot['id'], emoji: emoji);

      final removed = res['removed'] == true;
      final updated = List<Map<String, dynamic>>.from(res['reactions'] ?? []);
      final newCount = res['count'] ?? likeCount;
      final users = res['users'];

      if (!mounted) return;

      // Update local minimal state
      setState(() {
        liked = !removed;
        likeCount = newCount;
        myEmoji = removed ? null : emoji;
        if (users is List) {
          // keep reactionUsers if you display them (not storing here to reduce rebuilds)
        }
      });

      // Notify parent (feed) in a lightweight way (no rebuild on feed)
      widget.onLikeNetworkDone?.call(removed);
    } catch (e) {
      // fail silently but inform user
      if (mounted) {
        Fluttertoast.showToast(msg: "Échec réaction");
      }
      // We still notify parent to decrement pending counter
      widget.onLikeNetworkDone?.call(false);
    } finally {
      _reacting = false;
      await Future.delayed(const Duration(milliseconds: 180));
      if (mounted) setState(() => _likeAnimating = false);
    }
  }

  void _onLikeTap() {
    const defaultEmoji = '👍';
    if (liked) {
      _toggleReaction(myEmoji ?? defaultEmoji);
    } else {
      _toggleReaction(defaultEmoji);
    }
  }

  Future<void> _showReactionsPicker() async {
    final selected = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        elevation: 4,
        insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 260),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final e in ['❤️', '👍', '😂', '😮'])
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(e),
                  child: Text(e, style: const TextStyle(fontSize: 30)),
                ),
            ],
          ),
        ),
      ),
    );

    if (selected != null && selected.isNotEmpty) {
      await _toggleReaction(selected);
    }
  }

  // ---------- COMMENTS ----------
  Future<void> _openComments() async {
    final updatedCount = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => CommentsPage(
            publicationId: _pubSnapshot['id'], publication: _pubSnapshot),
      ),
    );
    if (updatedCount != null && updatedCount >= 0 && mounted) {
      setState(() {
        commentCount = updatedCount;
        userCommented = true;
      });
    }
  }

  // ---------- IMAGE PREVIEW ----------
  void _openPreview(List<String> imgs, int index) async {
    final prefs = await SharedPreferences.getInstance();
    final myId = int.tryParse(prefs.getString('user_id') ?? '0') ?? 0;
    final int authorId = _extractUserId(_pubSnapshot);
    final isMine = myId == authorId;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => ImagePreviewDialog(
        imageUrl: imgs[index],
        type: 'publication',
        authedDio: widget.authedDio,
        onChanged: (url) {
          Fluttertoast.showToast(
              msg: "📸 Photo mise à jour 🎉",
              backgroundColor: Colors.green,
              textColor: Colors.white);
          if (widget.isFromProfile) widget.onRefresh?.call();
        },
        onDelete: () {
          Fluttertoast.showToast(
              msg: "🗑️ Photo supprimée !",
              backgroundColor: Colors.redAccent,
              textColor: Colors.white);
          if (widget.isFromProfile) widget.onRefresh?.call();
        },
        canEdit: isMine,
      ),
    );
  }

  // ---------- UI BUILD ----------
  @override
  Widget build(BuildContext context) {
    super.build(context); // for AutomaticKeepAliveClientMixin

    // Local easy access
    final pub = _pubSnapshot;
    final auteur = _auteurSnapshot;
    final authorId = _extractUserId(pub);
    final isMe = (_myId != null && authorId != 0 && _myId == authorId);

    // --- EXTRAIT TEXTE & TYPE ---
    final String texte = (pub['texte'] ?? '').toString().trim();
    final String typePub =
        (pub['type_publication'] ?? '').toString().trim().toLowerCase();

    // 🔥 Ne jamais afficher un Reel dans le feed normal
    if (typePub == 'reel') return const SizedBox.shrink();

// --- MESSAGE AUTO PERSONNALISÉ ---
// --- MESSAGE AUTO PERSONNALISÉ (FORCÉ) ---
    Widget? autoLine;

    if (typePub == 'profil') {
      autoLine = _buildAutoLine(Icons.person, "A changé sa photo de profil");
    }

    if (typePub == 'cover') {
      autoLine = _buildAutoLine(
          Icons.landscape_rounded, "A changé sa photo de couverture");
    }

    // Files parsing (stable)
    final fichiersRaw = pub['fichiers'];
    List<String> fichiers = [];
    if (fichiersRaw is List) {
      fichiers = fichiersRaw.map((e) => e.toString()).toList();
    } else if (fichiersRaw is String && fichiersRaw.trim().isNotEmpty) {
      try {
        final parsed = json.decode(fichiersRaw);
        if (parsed is List) {
          fichiers = parsed.map((e) => e.toString()).toList();
        } else {
          fichiers = [fichiersRaw];
        }
      } catch (_) {
        fichiers = [fichiersRaw];
      }
    }

    // Top reaction display (not stored to avoid rebuilds)
    final reactions = pub['reactions'] is List
        ? List<Map<String, dynamic>>.from(pub['reactions'])
        : <Map<String, dynamic>>[];
    reactions.sort((a, b) => (b['c'] as int).compareTo(a['c'] as int));
// -----------------------------------------------------------
// 🔥 LOGIQUE POUR TEXTES AVEC BACKGROUND (<=80 caractères)
// -----------------------------------------------------------
    final String bgHex = (pub['background_color'] ?? '').toString();
    final bool hasBg =
        bgHex.isNotEmpty && bgHex != "null" && bgHex != "#transparent";

    Color? bgColor;

    if (hasBg) {
      try {
        bgColor = Color(int.parse("0xFF${bgHex.replaceFirst('#', '')}"));
      } catch (_) {
        bgColor = null;
      }
    }

    final bool useBgText = texte.isNotEmpty && hasBg && texte.length <= 80;

    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: Colors.transparent),
          Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(10),
              boxShadow: Theme.of(context).brightness == Brightness.light
                  ? const [BoxShadow(color: Colors.black12, blurRadius: 4)]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                ListTile(
                  leading: GestureDetector(
                    onTap: () {
                      if (authorId > 0) _openProfile(context, authorId);
                    },
                    child: CircleAvatar(
                      radius: 24,
                      backgroundImage:
                          CachedNetworkImageProvider(auteur['photo'] ?? ''),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                                child: Text(
                              (auteur['nom'] ?? '').toString(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            )),
                            if (auteur['badge_verified'] == 1 ||
                                auteur['badge_verified'] == '1')
                              const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: VerifiedBadge(
                                      isVerified: true, size: 14)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _timeAgo(pub['created_at']),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  trailing: widget.showMenu ? _buildMenu(context, isMe) : null,
                ),

// ---------------------- TEXT DISPLAY ----------------------
                if (autoLine != null) ...[
                  autoLine!
                ] else if (useBgText) ...[
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(
                            vertical: 8), // seulement vertical
                        decoration: BoxDecoration(
                          color: bgColor ?? Colors.black,
                          borderRadius:
                              BorderRadius.circular(0), // 🔥 bord à bord
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 40),
                        child: Text(
                          texte,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ))
                ] else if (texte.isNotEmpty) ...[
                  _buildTextBlock(texte)
                ],

                // Media
                if (fichiers.isNotEmpty) _buildMediaGrid(fichiers),

                // Reactions summary row (tap to open reactions)
                if (likeCount > 0)
                  InkWell(
                    onTap: _openReactionsPage,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 1, // 🔥 réduit
                        bottom: 3, // 🔥 réduit
                      ),
                      child: Row(
                        children: [
                          if (reactions.isNotEmpty)
                            Text((reactions.first['emoji'] ?? '👍').toString(),
                                style: const TextStyle(fontSize: 14))
                          else if (myEmoji != null)
                            Text(myEmoji!, style: const TextStyle(fontSize: 14))
                          else
                            const Icon(Icons.thumb_up_alt,
                                size: 14,
                                color: Color.fromARGB(255, 242, 24, 24)),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(_buildReactionsText(),
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 13))),
                        ],
                      ),
                    ),
                  ),

                const Divider(height: 1),

                // Buttons row (Like, Comment, Share)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Like
                      GestureDetector(
                        onTap: _onLikeTap,
                        onLongPress: _showReactionsPicker,
                        child: Column(
                          children: [
                            AnimatedScale(
                              scale: _likeAnimating ? 1.08 : 1.0,
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOut,
                              child: Icon(
                                Icons.thumb_up_alt,
                                size: 22,
                                color: liked
                                    ? const Color.fromARGB(255, 242, 24, 24)
                                    : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(_formatCount(likeCount),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: liked
                                        ? const Color.fromARGB(255, 242, 24, 24)
                                        : Colors.grey[700],
                                    fontWeight: liked
                                        ? FontWeight.bold
                                        : FontWeight.normal)),
                          ],
                        ),
                      ),

                      // Comments
                      GestureDetector(
                        onTap: _openComments,
                        child: Column(
                          children: [
                            Icon(Icons.comment_outlined,
                                size: 22,
                                color: userCommented
                                    ? const Color.fromARGB(255, 242, 24, 24)
                                    : Colors.grey[700]),
                            const SizedBox(height: 2),
                            Text(_formatCount(commentCount),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: userCommented
                                        ? const Color.fromARGB(255, 242, 24, 24)
                                        : Colors.grey[700],
                                    fontWeight: userCommented
                                        ? FontWeight.bold
                                        : FontWeight.normal)),
                          ],
                        ),
                      ),

                      // Share
// Share
                      GestureDetector(
                        onTap: () async {
                          final shared = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SharePublicationPage(
                                publicationId: _pubSnapshot['id'],
                              ),
                            ),
                          );

                          // ✅ si partage réel effectué
                          if (shared == true && mounted) {
                            setState(() => shareCount++);
                          }
                        },
                        child: Column(
                          children: [
                            Icon(
                              Icons.share_outlined,
                              size: 22,
                              color: shareCount > 0
                                  ? const Color.fromARGB(255, 242, 24, 24)
                                  : Colors.grey[700],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatCount(shareCount),
                              style: TextStyle(
                                fontSize: 12,
                                color: shareCount > 0
                                    ? const Color.fromARGB(255, 242, 24, 24)
                                    : Colors.grey[700],
                                fontWeight: shareCount > 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
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
        ],
      ),
    );
  }

  // ---------- small UI helpers ----------
  Widget _buildAutoLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 72, right: 12, bottom: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color: Color.fromARGB(255, 242, 24, 24), // 🔥 Rouge ZuaChat
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu(BuildContext context, bool isMe) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'delete') await _deletePublication();
        if (value == 'hide') await _maskPublication();
        if (value == 'save') {
          showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) =>
                  SaveToFolderDialog(publicationId: _pubSnapshot['id']));
        }
        if (value == 'remove') await _removeFromFolder();
      },
      itemBuilder: (_) {
        final items = <PopupMenuEntry<String>>[];

        if (widget.isSavedFolder) {
          return [
            const PopupMenuItem(
                value: 'remove',
                child: Row(children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text("Retirer du dossier")
                ]))
          ];
        }

        if (widget.isFromProfile || isMe) {
          items.add(const PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text("Supprimer")
              ])));
        }

        items.addAll([
          const PopupMenuItem(
              value: 'hide',
              child: Row(children: [
                Icon(Icons.visibility_off, color: Colors.grey),
                SizedBox(width: 8),
                Text("Masquer")
              ])),
          const PopupMenuItem(
              value: 'save',
              child: Row(children: [
                Icon(Icons.bookmark_border, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text("Enregistrer")
              ])),
        ]);

        return items;
      },
    );
  }

  // ---------------- TEXTE avec "voir plus" + copie ----------------
  Widget _buildTextBlock(String text) {
    if (text.isEmpty) return const SizedBox();

    bool isExpanded = false;
    const int maxLines = 2;

    return StatefulBuilder(
      builder: (ctx, setStateLocal) {
        return GestureDetector(
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: text));
            Fluttertoast.showToast(msg: "Texte copié ✔");
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  maxLines: isExpanded ? null : maxLines,
                  overflow:
                      isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                      ),
                ),
                if (text.length > 120)
                  GestureDetector(
                    onTap: () => setStateLocal(() => isExpanded = !isExpanded),
                    child: Text(
                      isExpanded ? "voir moins" : "voir plus",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaGrid(List<String> files) {
    final count = files.length;

    // ----------------------- CASE 1 : ONE IMAGE -----------------------
    if (count == 1) {
      final file = files.first;
      final isVideo = file.toLowerCase().endsWith('.mp4');

      return GestureDetector(
        onTap: () => _openPreview(files, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 1, // 🔥 FORMAT 1:1 FIXE
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: file,
                  fit: BoxFit.cover,
                ),
                if (isVideo)
                  const Center(
                    child: Icon(Icons.play_circle_fill,
                        color: Colors.white, size: 60),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // ----------------------- CASE 2 : TWO IMAGES -----------------------
    if (count == 2) {
      final itemSize = MediaQuery.of(context).size.width / 2 - 3;

      return SizedBox(
        height: itemSize, // 🔥 UNE SEULE LIGNE, PAS D'ESPACE EN BAS
        child: Row(
          children: [
            for (int i = 0; i < 2; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => _openPreview(files, i),
                  child: Container(
                    margin: EdgeInsets.only(right: i == 0 ? 3 : 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: files[i],
                            fit: BoxFit.cover,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // ----------------------- CASE 3+ : GRID 2×2 -----------------------
    final display = count > 4 ? 4 : count;
    final itemSize = MediaQuery.of(context).size.width / 2 - 3;

    return SizedBox(
      height: itemSize * 2 + 3,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
          childAspectRatio: 1, // 🔥 FORMAT 1:1 POUR TOUT
        ),
        itemCount: display,
        itemBuilder: (ctx, i) {
          final file = files[i];
          final isVideo = file.toLowerCase().endsWith('.mp4');

          return GestureDetector(
            onTap: () => _openPreview(files, i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: file,
                    fit: BoxFit.cover,
                  ),
                  if (isVideo)
                    const Center(
                      child: Icon(Icons.play_circle_fill,
                          color: Colors.white, size: 40),
                    ),
                  if (i == 3 && count > 4)
                    Container(
                      color: Colors.black45,
                      child: Center(
                        child: Text(
                          "+${count - 4}",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _buildReactionsText() {
    if (likeCount <= 0) return '';

    // Try to read reactionUsers from snapshot if available
    final reactionUsers = (_pubSnapshot['reaction_users'] is List)
        ? List<Map<String, dynamic>>.from(_pubSnapshot['reaction_users'])
        : <Map<String, dynamic>>[];

    if (reactionUsers.isEmpty) {
      return '$likeCount réactions';
    }

    Map<String, dynamic>? me;
    final others = <Map<String, dynamic>>[];

    for (final u in reactionUsers) {
      final id = int.tryParse('${u['user_id']}') ?? 0;
      if (_myId != null && _myId! > 0 && id == _myId) {
        me = u;
      } else {
        others.add(u);
      }
    }

    if (me != null) {
      if (others.isEmpty) return 'Vous';
      final first = others.first;
      final firstName =
          ((first['prenom'] ?? first['nom'] ?? first['username']) ??
                  'Quelqu’un')
              .toString()
              .trim();
      final remaining = likeCount - 2;
      if (remaining <= 0) return 'Vous et $firstName';
      if (remaining == 1) return 'Vous, $firstName et 1 autre';
      return 'Vous, $firstName et $remaining autres';
    } else {
      if (others.isEmpty) return '$likeCount réactions';
      final first = others.first;
      final firstName =
          ((first['prenom'] ?? first['nom'] ?? first['username']) ??
                  'Quelqu’un')
              .toString()
              .trim();
      final remaining = likeCount - 1;
      if (remaining <= 0) return firstName;
      if (remaining == 1) return '$firstName et 1 autre';
      return '$firstName et $remaining autres';
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return "à l’instant";
    if (diff.inMinutes < 60) return "il y a ${diff.inMinutes} min";
    if (diff.inHours < 24) return "il y a ${diff.inHours} h";
    if (diff.inDays < 7) return "il y a ${diff.inDays} j";
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) return "il y a $weeks sem";
    final months = (diff.inDays / 30).floor();
    if (months < 12) return "il y a $months mois";
    final years = (diff.inDays / 365).floor();
    return "il y a $years an${years > 1 ? 's' : ''}";
  }
}
