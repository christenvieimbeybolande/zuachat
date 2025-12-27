import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../api/comments.dart';
import '../api/react_comment.dart';
import '../widgets/verified_badge.dart';
import '../widgets/publication_card.dart';
import '../api/client.dart';

class CommentsPage extends StatefulWidget {
  final int publicationId;
  final Map<String, dynamic>? publication;

  const CommentsPage({
    super.key,
    required this.publicationId,
    this.publication,
  });

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  List<dynamic> _comments = [];
  bool _loading = true;
  bool _sending = false;
  int? _replyTo;
  final Set<int> _expanded = {};

  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadMyId();
    _loadComments();
  }

  Future<void> _loadMyId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = int.tryParse(prefs.getString('user_id') ?? '');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ==============================
  // 🔄 Chargement des commentaires
  // ==============================
  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final data = await apiFetchComments(widget.publicationId);
      setState(() => _comments = data);
    } catch (e) {
      Fluttertoast.showToast(msg: "Erreur de chargement : $e");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ==============================
  // ✉️ Envoi commentaire
  // ==============================
  Future<void> _sendComment() async {
    final texte = _controller.text.trim();
    if (texte.isEmpty) return;

    HapticFeedback.selectionClick(); // 🩵 petit clic doux

    setState(() => _sending = true);

    try {
      await apiAddComment(
        publicationId: widget.publicationId,
        texte: texte,
        parentId: _replyTo,
      );
      _controller.clear();
      _replyTo = null;
      _focusNode.unfocus();
      await _loadComments();
    } catch (e) {
      Fluttertoast.showToast(msg: "Erreur : $e");
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  // ==============================
  // ⏱️ Temps relatif
  // ==============================
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

  // ==============================
  // 1K / 1.2K / 3M format
  // ==============================
  String _formatCount(int n) {
    if (n >= 1000000) {
      final v = n / 1000000.0;
      if (v == v.floorToDouble()) return "${v.toInt()} M";
      return "${v.toStringAsFixed(1)} M";
    } else if (n >= 1000) {
      final v = n / 1000.0;
      if (v == v.floorToDouble()) return "${v.toInt()} K";
      return "${v.toStringAsFixed(1)} K";
    }
    return n.toString();
  }

  // ==============================
  // Nom complet
  // ==============================
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

  // ==============================
  // Photo profil
  // ==============================
  String _buildPhoto(String? url) {
    if (url == null || url.isEmpty) {
      return 'https://zuachat.com/assets/default-avatar.png';
    }
    if (url.startsWith('http')) return url;
    return 'https://zuachat.com/$url';
  }

  // ==============================
  // 🔢 Récupération des réactions d'un commentaire
  // ==============================
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

  // ==============================
  // 🔹 Widget affichage réactions
  // ==============================
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
            Text(
              emoji,
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(width: 2),
            Text(
              _formatCount(count),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[800],
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
          color: isDark ? const Color(0xFF2A2B2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: chips,
        ),
      ),
    );
  }

  // ==============================
  // 💬 Commentaire principal animé
  // ==============================
  Widget _buildAnimatedComment(dynamic c, int index) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 40)),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: child,
          ),
        );
      },
      child: _buildComment(c),
    );
  }

  // ==============================
  // 💬 Bloc principal de commentaire
  // ==============================
  Widget _buildComment(dynamic c) {
    final replies = (c['replies'] ?? []) as List;
    final verified = c['badge_verified'] == 1;
    final photo = _buildPhoto(c['photo']);
    final isOwner = c['user_id'] == _userId;
    final nomAuteur = _buildName(c);

    return GestureDetector(
      onLongPress: () => _showOptions(c, isOwner),
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
                          color: isDark
                              ? const Color(0xFF242526)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Flexible(
                                  child: Text(
                                    nomAuteur,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                                VerifiedBadge.mini(isVerified: verified),
                              ]),
                              const SizedBox(height: 2),
                              Text(
                                c['texte'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ]),
                      ),
                      // 🔹 Réactions juste en dessous de la bulle
                      _buildReactionsBubble(c),
                      const SizedBox(height: 2),
                      Row(children: [
                        TextButton(
                          onPressed: () {
                            setState(() => _replyTo = c['id']);
                            Future.delayed(const Duration(milliseconds: 100),
                                () {
                              FocusScope.of(context).requestFocus(_focusNode);
                            });
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                          ),
                          child: const Text(
                            "Répondre",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _timeAgo(c['created_at']),
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ]),
                    ]),
              ),
            ]),
            if (replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 45, top: 3),
                child: !_expanded.contains(c['id'])
                    ? TextButton(
                        onPressed: () => setState(() => _expanded.add(c['id'])),
                        child: Text(
                          "Afficher les réponses (${replies.length})",
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1877F2),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextButton(
                            onPressed: () =>
                                setState(() => _expanded.remove(c['id'])),
                            child: const Text(
                              "Masquer les réponses",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
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
    );
  }

  // ==============================
  // 💬 Réponse
  // ==============================
  Widget _buildReply(dynamic r, dynamic parent) {
    final verified = r['badge_verified'] == 1;
    final photo = _buildPhoto(r['photo']);
    final isOwner = r['user_id'] == _userId;
    final nomAuteur = _buildName(r);

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 15),
          child: child,
        ),
      ),
      child: GestureDetector(
        onLongPress: () => _showOptions(r, isOwner),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 40),
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
                  color:
                      isDark ? const Color(0xFF242526) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(
                          nomAuteur,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      VerifiedBadge.mini(isVerified: verified),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      r['texte'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    // 🔹 Réactions sur la réponse aussi
                    _buildReactionsBubble(r),
                    const SizedBox(height: 2),
                    Row(children: [
                      TextButton(
                        onPressed: () {
                          setState(() => _replyTo = parent['id']);
                          _controller.clear();
                          Future.delayed(const Duration(milliseconds: 100), () {
                            FocusScope.of(context).requestFocus(_focusNode);
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                        ),
                        child: const Text(
                          "Répondre",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _timeAgo(r['created_at']),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
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
  // ⚙️ Menu options (avec réactions)
  // ==============================
  void _showOptions(dynamic c, bool isOwner) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF242526) : Colors.white,
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
                        HapticFeedback
                            .selectionClick(); // 🩵 au moment de réagir
                        try {
                          final res = await apiReactToComment(
                            commentId: c['id'],
                            emoji: emoji,
                          );
                          Fluttertoast.showToast(
                            msg: res['message'] ?? "Réaction enregistrée",
                          );
                          _loadComments();
                        } catch (e) {
                          Fluttertoast.showToast(msg: e.toString());
                        }
                      },
                      child: Text(
                        emoji,
                        style: TextStyle(fontSize: 26),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_reaction_outlined,
                      color: Colors.grey,
                    ),
                    onPressed: () => Fluttertoast.showToast(
                      msg: "Sélecteur d’emojis à venir...",
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.reply,
                  color: isDark ? Colors.white : Colors.black),
              title: Text(
                'Répondre',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyTo = c['id']);
                FocusScope.of(context).requestFocus(_focusNode);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copier le texte'),
              onTap: () {
                Clipboard.setData(
                  ClipboardData(text: c['texte'] ?? ''),
                );
                Navigator.pop(context);
                Fluttertoast.showToast(msg: "Commentaire copié !");
              },
            ),
            if (isOwner) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Modifier'),
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

  // ==============================
  // ✏️ Edition commentaire
  // ==============================
  Future<void> _editComment(dynamic c) async {
    final ctrl = TextEditingController(text: c['texte']);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Modifier le commentaire"),
        content: TextField(
          controller: ctrl,
          maxLines: null,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "Nouveau texte...",
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
        await _loadComments();
      } catch (e) {
        Fluttertoast.showToast(msg: e.toString());
      }
    }
  }

  // ==============================
  // 🗑️ Suppression commentaire
  // ==============================
  Future<void> _deleteComment(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer ?"),
        content: const Text("Voulez-vous supprimer ce commentaire ?"),
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
        await _loadComments();
      } catch (e) {
        Fluttertoast.showToast(msg: e.toString());
      }
    }
  }

  // ==============================
  // 🧱 Interface principale
  // ==============================
  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF18191A) : Colors.white;
    final cardColor = isDark ? const Color(0xFF242526) : Colors.grey.shade100;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.grey;
    final pub = widget.publication;
    final auteurNom = pub?['auteur']?['prenom'] != null
        ? "${pub?['auteur']?['prenom']} ${pub?['auteur']?['nom']}"
        : "Auteur";

    final viewInsets = MediaQuery.of(context).viewInsets;

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 0, 0), // 🔴 rouge
        foregroundColor: Colors.white, // ⬅️ flèche blanche
        title: Text(
          "Publication de $auteurNom",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // 🔼 Partie principale (publication + commentaires)
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      itemCount: _comments.length +
                          (widget.publication != null ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (widget.publication != null && index == 0) {
                          return Column(
                            children: [
                              PublicationCard(
                                publication: widget.publication!,
                                authedDio: ApiClient.authed,
                                onRefresh: _loadComments,
                              ),
                              const Divider(height: 1),
                            ],
                          );
                        }

                        final comment = _comments[
                            index - (widget.publication != null ? 1 : 0)];
                        return _buildAnimatedComment(comment, index);
                      },
                    ),
            ),

            // 🔽 Champ de saisie fixé au bas de l’écran
            SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      blurRadius: 3,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        controller: _controller,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.send,
                        maxLines: 3,
                        minLines: 1,
                        onSubmitted: (_) => _sendComment(),
                        decoration: InputDecoration(
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white60 : Colors.grey,
                          ),
                          hintText: _replyTo == null
                              ? "Écrire un commentaire..."
                              : "Répondre à un commentaire...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                              width: 0.8,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _sending
                        ? const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color.fromARGB(255, 242, 24, 24),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send,
                                color: Color.fromARGB(255, 242, 24, 24)),
                            onPressed: _sendComment,
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
