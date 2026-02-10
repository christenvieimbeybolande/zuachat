import 'dart:io';
import 'dart:async'; // ✅ OBLIGATOIRE POUR Timer
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/publication_card.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/zua_loader_mini.dart';

import '../api/home_feed.dart';
import '../api/client.dart';

import 'messages_page.dart'; // en haut du fichier
import 'all_status_page.dart';
import 'add_publication_page.dart';
import 'login_page.dart';
import 'story_editor_page.dart';
import 'story_viewer_page.dart';
import '../utils/feed_ranker.dart';
import 'search_page.dart';
import 'reels_page.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  // ------------------------------
  // STATE
  // ------------------------------
  Map<String, dynamic>? _data;

  bool _loading = true;
  bool _refreshing = false;
  bool _isLoadingMore = false;
  int unreadNotifications = 0;
  int unreadMessages = 0;
  Timer? _pollingTimer;
  bool _offline = false;

  final ScrollController _scrollController = ScrollController();

  // FEED PAGINATION
  int _page = 1;
  static const int _limit = 20;

  // Liste interne des publications fusionnées
  final List<Map<String, dynamic>> _publications = [];

  // 🔥 BARRE SYNC LIKE
  final ValueNotifier<int> _pendingLikes = ValueNotifier(0);
  final ValueNotifier<bool> _showSyncBar = ValueNotifier(false);
  final ValueNotifier<bool> _lastWasAdd = ValueNotifier(true);

  late AnimationController _animCtrl;

  static const primaryColor = Color(0xFFFF0000);

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _scrollController.addListener(_handleScroll);
    _checkAuthState();

    // 🔁 POLLING FEED (compteurs seulement)
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (!mounted) return;
        _pollCountsOnly();
      },
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel(); // ✅ OBLIGATOIRE
    _animCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // AUTH CHECK
  // ============================================================
  Future<void> _checkAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('access_token') == null) {
      _redirectToLogin();
    } else {
      _load(reset: true);
    }
  }

  void _redirectToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // ============================================================
  // LOAD FEED (RESET ou PAGE 1)
  // ============================================================
  Future<void> _load({bool reset = false, bool refresh = false}) async {
    if (!mounted) return;

    if (reset) {
      _page = 1;
      _publications.clear();
    }

    double? oldPos;
    if (refresh && _scrollController.hasClients) {
      oldPos = _scrollController.offset;
      setState(() => _refreshing = true);
    }

    try {
      final res = await fetchHomeFeed(page: _page, limit: _limit);
      if (res['ok'] != true) throw Exception("Erreur");

      // 1️⃣ Charger les publications
      final newPubs =
          List<Map<String, dynamic>>.from(res['publications'] ?? []);

      // 2️⃣ Appliquer le tri intelligent
      final ranked = FeedRanker.rank(newPubs);

      setState(() {
        _data = res;
        _loading = false;
        _refreshing = false;
        _offline = false;

        unreadNotifications = res['unread_notifications'] ?? 0;
        unreadMessages = res['unread_messages'] ?? 0;

        if (_page == 1) {
          _publications.clear();
        }

        _publications.addAll(ranked);
      });

// ✅ AJOUT ICI
      if (_offline) {
        setState(() => _offline = false);
      }

      _animCtrl.forward(from: 0.0);

      // Restauration du scroll
      if (refresh && oldPos != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final max = _scrollController.position.maxScrollExtent;
          final newOffset = oldPos!.clamp(0.0, max).toDouble();
          _scrollController.jumpTo(newOffset);
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _offline = true; // 🔔 PAS DE CONNEXION
        _loading = false;
        _refreshing = false;
      });

      // 🔁 retry silencieux (sans UI bloquante)
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _offline) {
          _load(reset: false);
        }
      });
    }
  }

  Future<void> _pollCountsOnly() async {
    try {
      final res = await fetchHomeFeed(page: 1, limit: 1);

      if (res['ok'] == true && mounted) {
        if (_offline) {
          setState(() => _offline = false);
        }

        setState(() {
          unreadMessages = res['unread_messages'] ?? unreadMessages;
          unreadNotifications =
              res['unread_notifications'] ?? unreadNotifications;
        });
      }
    } catch (_) {
      // silence volontaire
    }
  }

  // ============================================================
  // INFINITE SCROLL
  // ============================================================
  void _handleScroll() {
    if (_isLoadingMore) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    _page++;

    try {
      final res = await fetchHomeFeed(page: _page, limit: _limit);

      if (res['ok'] == true) {
        final fresh =
            List<Map<String, dynamic>>.from(res['publications'] ?? []);

        if (fresh.isNotEmpty) {
          final ranked = FeedRanker.rank(fresh);

          setState(() {
            _publications.addAll(ranked);
          });
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _onRefresh() async {
    return _load(reset: true, refresh: true);
  }

  // ============================================================
  // LIKE SYNC BAR
  // ============================================================
  void onLikeStart() {
    _pendingLikes.value++;
    _showSyncBar.value = true;
  }

  void onLikeDone(bool removed) {
    if (_pendingLikes.value > 0) {
      _pendingLikes.value--;
    }

    _lastWasAdd.value = !removed;

    if (_pendingLikes.value == 0) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (_pendingLikes.value == 0) {
          _showSyncBar.value = false;
        }
      });
    }
  }

  Widget _buildSyncBar() {
    return ValueListenableBuilder(
      valueListenable: _showSyncBar,
      builder: (_, show, __) {
        if (!show) return const SizedBox.shrink();

        return ValueListenableBuilder(
          valueListenable: _pendingLikes,
          builder: (_, pending, __) {
            final bool still = pending > 0;

            return ValueListenableBuilder(
              valueListenable: _lastWasAdd,
              builder: (_, lastAdd, __) {
                final color = still
                    ? Colors.red
                    : (lastAdd ? Colors.green : Colors.orange);

                final text = still
                    ? "Actions en attente : $pending"
                    : (lastAdd ? "Like envoyé " : "Like retiré");

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.09),
                    border: Border(
                      top: BorderSide(color: color.withOpacity(0.3)),
                      bottom: BorderSide(color: color.withOpacity(0.3)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        still ? Icons.sync : Icons.check_circle,
                        size: 16,
                        color: color,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          text,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 70,
                        child: LinearProgressIndicator(
                          value: still ? null : 1,
                          minHeight: 3,
                          color: color,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: ListView.builder(
          itemCount: 3,
          padding: const EdgeInsets.all(14),
          itemBuilder: (_, __) {
            return Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 260,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          },
        ),
      );
    }

    final d = _data ?? {};

    final user = d['user'] ?? {};
    final List statuts = (d['statuts'] is List) ? d['statuts'] : [];
    final sponsor = d['sponsorises'] ?? [];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: const Text(
          "ZuaChat",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          // 🎬 REELS (NOUVEAU)
          IconButton(
            tooltip: "Reels",
            icon: const Icon(Icons.video_collection, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReelsPage(initialReelId: 0),
                ),
              );
            },
          ),

          // 🔄 REFRESH
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 22,
                height: 22,
                child: ZuaLoaderMini(),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => _load(reset: true),
            ),

          // 🔍 SEARCH
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchPage()),
              );
            },
          ),

          // ✉ MESSAGES
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MessageListPage()),
              );
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.mail_outline, color: Colors.white),
                if (unreadMessages > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        unreadMessages > 9 ? '9+' : unreadMessages.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color.fromARGB(255, 255, 0, 0),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ➕ ADD
          IconButton(
            icon: const Icon(Icons.add_circle, size: 24, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddPublicationPage(),
                ),
              );
            },
          ),
        ],
      ),

      // ============================================================
      // BODY
      // ============================================================
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: _onRefresh,
        child: Column(
          children: [
            // 🔥 La barre Sync Like sous l’AppBar
            ValueListenableBuilder(
              valueListenable: _showSyncBar,
              builder: (_, show, __) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: show ? 22 : 0, // 👈 FIX hauteur AppBar
                  child: show ? _buildSyncBar() : const SizedBox.shrink(),
                );
              },
            ),
            if (_offline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                color: Colors.orange.shade200,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.wifi_off, size: 14),
                    SizedBox(width: 6),
                    Text(
                      "Hors connexion, l'accueil se synchronisera automatiquement",
                      style: TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ),

            // 🔥 Le reste du feed
            Expanded(
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _animCtrl,
                  curve: Curves.easeInOut,
                ),
                child: ListView(
                  key: const PageStorageKey("feed_list"),
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 10, bottom: 10),
                  children: [
                    _buildStories(user, statuts),
                    const SizedBox(height: 6),
                    _buildThinkingBox(user),
                    const SizedBox(height: 6),
                    if (_publications.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            "Aucune publication pour l’instant ",
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        itemCount: _publications.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (_, i) {
                          final p = _publications[i];

                          // 🔥 Ignorer les Reels dans le feed normal
                          if ((p['type_publication'] ?? '')
                                  .toString()
                                  .toLowerCase() ==
                              'reel') {
                            return const SizedBox.shrink();
                          }

                          return PublicationCard(
                            key: ValueKey("pub_${p['id']}"),
                            publication: p,
                            authedDio: () async => (await ApiClient.authed()),
                            onRefresh: () => _load(reset: true),
                            onLikeNetworkStart: onLikeStart,
                            onLikeNetworkDone: (removed) => onLikeDone(removed),
                            isFromProfile: false,
                          );
                        },
                      ),
                    if (sponsor.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          "Sponsorisé",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...sponsor.map((s) => _buildSponsorCard(s)).toList(),
                    ],
                    if (_isLoadingMore)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: BottomNav(
        currentIndex: 0,
        unreadNotifications: unreadNotifications,
        unreadMessages: unreadMessages,
      ),
    );
  }

// ============================================================
// STORIES LIST — l’utilisateur d’abord + "Mon statut"
// ============================================================
  Widget _buildStories(dynamic user, List statuts) {
    Map<String, dynamic>? myStatut;

    if (statuts.isNotEmpty && statuts.first["user_id"] == user["id"]) {
      myStatut = statuts.first; // mon statut
    }

    return SizedBox(
      height: 115,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 2 + statuts.length,
        // 0 = ajouter
        // 1 = voir plus
        // 2.. = statuts
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          if (index == 0) return _buildAddStatut(user);

          if (index == 1) return _buildVoirPlus();

          // S'il existe mon statut, afficher en priorité
          if (index == 2 && myStatut != null) {
            return _buildStatutItem(myStatut, isMe: true);
          }

          final realIndex = myStatut != null ? index - 2 : index - 1;

          if (realIndex < 0 || realIndex >= statuts.length) {
            return const SizedBox.shrink();
          }

          final s = statuts[realIndex];
          return _buildStatutItem(s, isMe: false);
        },
      ),
    );
  }

// ============================================================
// ADD STORY TILE
// ============================================================
  Widget _buildAddStatut(dynamic user) {
    final String avatar = user['photo'] ?? "";
    final avatarUrl =
        avatar.startsWith("http") ? avatar : "https://zuachat.com/$avatar";

    return GestureDetector(
      onTap: () async {
        final pick = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (pick == null) return;

        final pub = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                StoryEditorPage(mediaFile: File(pick.path), isVideo: false),
          ),
        );

        if (pub == true) _load(reset: true);
      },
      child: SizedBox(
        width: 90,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [primaryColor, Color(0xFF42A5F5)],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 37,
                    backgroundColor: Theme.of(context).cardColor,
                    backgroundImage: CachedNetworkImageProvider(avatarUrl),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Ajouter",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoirPlus() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AllStatusPage()),
        );
      },
      child: SizedBox(
        width: 90,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: primaryColor, width: 2),
              ),
              child: CircleAvatar(
                radius: 37,
                backgroundColor: Colors.white,
                backgroundImage: const CachedNetworkImageProvider(
                  "https://zuachat.com/assets/statut-default.png",
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Voir plus",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatutItem(dynamic s, {bool isMe = false}) {
    final int id = int.tryParse("${s['id']}") ?? 0;

    String img = s['media_path'] ?? s['photo'] ?? "";
    if (!img.startsWith("http")) {
      img = "https://zuachat.com/$img";
    }

    final String label =
        isMe ? "Mon statut" : "${s['prenom'] ?? ''} ${s['nom'] ?? ''}".trim();

    return GestureDetector(
      onTap: id > 0
          ? () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoryViewerPage(statutId: id),
                ),
              );
              _load(reset: true);
            }
          : null,
      child: SizedBox(
        width: 90,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [primaryColor, Color(0xFF42A5F5)],
                ),
              ),
              child: CircleAvatar(
                radius: 37,
                backgroundColor: Colors.white,
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: img,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // THINKING BOX
  Widget _buildThinkingBox(dynamic user) {
    final String avatar = user['photo'] ?? "";
    final avatarUrl =
        avatar.startsWith("http") ? avatar : "https://zuachat.com/$avatar";

    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddPublicationPage()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundImage: CachedNetworkImageProvider(avatarUrl),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "À quoi pensez-vous ?",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // SPONSOR CARD
  Widget _buildSponsorCard(dynamic a) {
    String img = a['image'] ?? "";
    if (!img.startsWith("http")) {
      img = "https://zuachat.com/$img";
    }

    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      child: Column(
        children: [
          if (img.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              child: CachedNetworkImage(
                imageUrl: img,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              a['titre'] ?? "",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
