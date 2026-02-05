import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import '../widgets/verified_badge.dart';
import '../widgets/zua_loader.dart';

import 'profile_albums_page.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/zua_loader_mini.dart';
import '../widgets/publication_card.dart';
import '../widgets/image_preview_dialog.dart';
import '../api/fetch_profile.dart';
import '../api/fetch_publications.dart';
import '../api/update_bio.dart';
import '../api/client.dart';
import 'feed_page.dart';
import 'edit_profile_page.dart';
import 'followers_page.dart'; // 👈 IMPORTANT
import 'following_page.dart'; // 👈 IMPORTANT
import 'my_reels_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _publications = [];
  bool _loading = true;
  bool _error = false;
  int unreadNotifications = 0;
  int unreadMessages = 0;

  bool _pubsLoading = true;
  bool _pubsError = false;

  bool _editingBio = false;
  bool _savingBio = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final ImagePicker _picker = ImagePicker();
  final CancelToken _cancelToken = CancelToken();
  final TextEditingController _bioCtrl = TextEditingController();

  static const _primary = Color.fromARGB(255, 255, 0, 0);
  static const _bg = Color(0xFFF0F2F5);

  Future<Dio> _authedDio() async => await ApiClient.authed();

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadCounters(); // 🔔 BADGES
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _cancelToken.cancel('Page fermée');
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = false;
      _pubsLoading = true;
    });

    try {
      final res = await fetchProfile();
      final d = (res['data'] ?? res) as Map<String, dynamic>;
      if (!mounted) return;

      _data = d;

      // BIO
      _bioCtrl.text = (_data?['user']?['bio'] ?? '').toString();

      // 🔥 Publications venant directement de l'API PHP
      final uid = int.tryParse('${_data!['user']['id']}');
      await _loadPublications(uid);

      _loading = false;
      _pubsLoading = false;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      _loading = false;
      _error = true;
      if (kDebugMode) debugPrint('❌ Erreur fetchProfile: $e');
    }
  }

  Future<void> _loadPublications(int? userId) async {
    setState(() {
      _pubsLoading = true;
      _pubsError = false;
    });
    try {
      final res = await fetchPublications(userId: userId);
      if (!mounted) return;

      if (res['success'] == true) {
        final list = (res['data'] as List?) ?? [];
        _publications.clear();
        _publications.addAll(list
            .whereType<Map>()
            .map<Map<String, dynamic>>((e) => e.cast<String, dynamic>()));

        _pubsLoading = false;
      } else {
        _pubsLoading = false;
        _pubsError = true;
      }
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      _pubsLoading = false;
      _pubsError = true;
      setState(() {});
    }
  }

  Future<void> _loadCounters() async {
    try {
      final dio = await ApiClient.authed();
      final res = await dio.get('/home_feed.php');

      if (!mounted) return;

      if (res.data is Map && res.data['ok'] == true) {
        setState(() {
          unreadNotifications = res.data['unread_notifications'] ?? 0;
          unreadMessages = res.data['unread_messages'] ?? 0;
        });
      }
    } catch (_) {
      // on ignore, pas bloquant
    }
  }

  Future<void> _changeProfilePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    try {
      final dio = await _authedDio();
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(picked.path),
      });
      final res = await dio.post(
        'https://zuachat.com/api/update_photo.php',
        data: formData,
        cancelToken: _cancelToken,
      );
      if (res.data is Map && res.data['success'] == true) {
        setState(() => _data!['user']['photo'] = res.data['url']);
        _snack('Photo de profil mise à jour ✅');
      } else {
        _snack(res.data['message'] ?? 'Erreur mise à jour', error: true);
      }
    } catch (e) {
      _snack('Erreur connexion ⚠️', error: true);
    }
  }

  Future<void> _changeCoverPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    try {
      final dio = await _authedDio();
      final formData = FormData.fromMap({
        'couverture': await MultipartFile.fromFile(picked.path),
      });
      final res = await dio.post(
        'https://zuachat.com/api/update_cover.php',
        data: formData,
        cancelToken: _cancelToken,
      );
      if (res.data is Map && res.data['success'] == true) {
        setState(() => _data!['user']['couverture'] = res.data['url']);
        _snack('Photo de couverture mise à jour ✅');
      } else {
        _snack(res.data['message'] ?? 'Erreur mise à jour', error: true);
      }
    } catch (e) {
      _snack('Erreur connexion ⚠️', error: true);
    }
  }

  Future<void> _updateBio() async {
    final newBio = _bioCtrl.text.trim();
    if (newBio.isEmpty) {
      _snack('Votre bio ne peut pas être vide', error: true);
      return;
    }
    setState(() => _savingBio = true);
    try {
      final result = await updateBio(newBio);
      if (result['success'] == true) {
        setState(() {
          _data!['user']['bio'] = newBio;
          _editingBio = false;
        });
        _snack('Bio mise à jour ✅');
      } else {
        _snack(result['message'] ?? 'Erreur mise à jour bio', error: true);
      }
    } catch (e) {
      _snack('Erreur connexion ⚠️', error: true);
    } finally {
      if (mounted) setState(() => _savingBio = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  // ---------------- Helpers ----------------
  String _s(dynamic v, [String fb = '']) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? fb : s;
  }

  String _url(dynamic v, String fb) {
    final s = (v ?? '').toString().trim();
    if (s.isEmpty) return fb;
    return s.replaceAll('/../', '/');
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: ZuaLoader(size: 140, looping: true),
        ),
      );
    }

    if (_error || _data == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              ZuaLoader(size: 130, looping: true),
              SizedBox(height: 20),
              Text(
                "Connexion lente... Tentative automatique",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final user = _data!['user'] as Map<String, dynamic>;

    final nomAffiche = (user['type_compte'] == 'professionnel')
        ? (user['nom'] ?? 'Utilisateur')
        : "${user['prenom'] ?? ''} ${user['nom'] ?? ''} ${user['postnom'] ?? ''}"
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    final username = _s(user['username']);
    final isVerified = (user['badge_verified'] == 1);

    final cover = _url(
      user['couverture'],
      'https://zuachat.com/assets/couverture-default.jpg',
    );
    final avatar = _url(
      user['photo'],
      'https://zuachat.com/assets/default-avatar.png',
    );

    final followers = _s(user['followers'], '0');
    final following = _s(user['following'], '0');
    final pays = _s(user['pays']);
    final sexe = _s(user['sexe']);
    final tel = _s(user['telephone']);
    final email = _s(user['email']);
    final dob = _s(user['date_naissance']);
    final theme = _s(user['theme'], 'light');
    final typeCompte = _s(user['type_compte'], 'personnel');
    final categorie = _s(user['categorie']);

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FeedPage()),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,

        body: RefreshIndicator(
          color: _primary,
          onRefresh: () async {
            await _loadProfile();
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // --- 🔵 HEADER (Cover + Avatar) ---
              SliverAppBar(
                pinned: true,
                backgroundColor: _primary,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const FeedPage()),
                    );
                  },
                ),
                expandedHeight: MediaQuery.of(context).size.width * 9 / 16,
                flexibleSpace: LayoutBuilder(
                  builder: (context, cons) {
                    final raw = (cons.maxHeight - kToolbarHeight) /
                        (260 - kToolbarHeight);
                    final t = raw.isNaN ? 0.0 : raw.clamp(0.0, 1.0);
                    final avatarSize = 120.0 * (0.6 + 0.4 * t);

                    return Stack(
                      clipBehavior: Clip.none,
                      fit: StackFit.expand,
                      children: [
                        // --- IMAGE COVER ---
                        CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: Colors.black26),
                          errorWidget: (_, __, ___) =>
                              Container(color: Colors.black26),
                        ),

                        // --- GRADIENT EN BAS ---
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: 120,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black54],
                              ),
                            ),
                          ),
                        ),

                        // --- PHOTO DE PROFIL ---
                        Positioned(
                          bottom: -avatarSize / 2.3,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => ImagePreviewDialog(
                                    imageUrl: avatar,
                                    type: 'profile',
                                    authedDio: _authedDio,
                                    onChanged: (url) => setState(
                                        () => _data!['user']['photo'] = url),
                                    onMessage: (msg) => _snack(msg),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 3),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: avatarSize / 2,
                                  backgroundColor: Colors.white,
                                  backgroundImage:
                                      CachedNetworkImageProvider(avatar),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // --- COVER CLICKABLE ---
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          bottom: 80,
                          child: GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => ImagePreviewDialog(
                                  imageUrl: cover,
                                  type: 'cover',
                                  authedDio: _authedDio,
                                  onChanged: (url) => setState(
                                      () => _data!['user']['couverture'] = url),
                                  onMessage: (msg) => _snack(msg),
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

              // --- 🔵 CARTE PROFIL ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      14, 30, 14, 12), // 🔥 pousser la carte derrière
                  child: Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                nomAffiche,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 6),
                                const VerifiedBadge(isVerified: true, size: 18),
                              ],
                            ],
                          ),

                          if (username.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '@$username',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 14),
                              ),
                            ),

                          const SizedBox(height: 12),

                          // --- BIO ---
                          _editingBio
                              ? Column(
                                  children: [
                                    TextField(
                                      controller: _bioCtrl,
                                      maxLines: null,
                                      decoration: InputDecoration(
                                        hintText: 'Écrivez votre bio...',
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed:
                                              _savingBio ? null : _updateBio,
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: _primary),
                                          icon: _savingBio
                                              ? const ZuaLoaderMini()
                                              : const Icon(Icons.save),
                                          label: Text(_savingBio
                                              ? 'Sauvegarde...'
                                              : 'Enregistrer'),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton(
                                          onPressed: _savingBio
                                              ? null
                                              : () => setState(
                                                  () => _editingBio = false),
                                          child: const Text('Annuler'),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              : InkWell(
                                  onTap: () =>
                                      setState(() => _editingBio = true),
                                  child: Text(
                                    _s(user['bio'], 'Ajouter une bio...'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _s(user['bio']).isNotEmpty
                                          ? Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color
                                          : Theme.of(context).hintColor,
                                      fontStyle: _s(user['bio']).isNotEmpty
                                          ? FontStyle.italic
                                          : FontStyle.normal,
                                    ),
                                  ),
                                ),

                          const SizedBox(height: 14),

                          // --- FOLLOWERS / FOLLOWING ---
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              InkWell(
                                onTap: () async {
                                  final changed = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            FollowersPage(userId: user['id'])),
                                  );

                                  if (changed == true) {
                                    final uid = int.tryParse('${user['id']}');
                                    _loadPublications(
                                        uid); // ❗ PAS _loadProfile()
                                  }
                                },
                                child: _statChip(
                                    Icons.people, 'abonnés', followers),
                              ),
                              InkWell(
                                onTap: () async {
                                  final changed = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            FollowingPage(userId: user['id'])),
                                  );

                                  if (changed == true) {
                                    final uid = int.tryParse('${user['id']}');
                                    _loadPublications(
                                        uid); // ❗ PAS _loadProfile()
                                  }
                                },
                                child: _statChip(
                                    Icons.person_add, 'abonnements', following),
                              ),
                              _statChip(Icons.article, 'publications',
                                  _s(user['publications_total'], '0')),
                            ],
                          ),

                          const SizedBox(height: 14),

                          _infoGrid([
                            _infoItem(Icons.email, email),
                            _infoItem(Icons.phone, tel),
                            _infoItem(Icons.flag, pays),
                            if (typeCompte != 'professionnel')
                              _infoItem(Icons.wc, sexe),
                            if (typeCompte != 'professionnel')
                              _infoItem(Icons.cake, dob),
                            _infoItem(Icons.color_lens, "Thème : $theme"),
                            _infoItem(
                                Icons.account_circle, "Type : $typeCompte"),
                            if (typeCompte == 'professionnel' &&
                                categorie.isNotEmpty)
                              _infoItem(Icons.business_center,
                                  "Catégorie : $categorie"),
                          ]),

                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const EditProfilePage()));
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.edit, color: Colors.white),
                              label: const Text('Modifier mon profil',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // --- 🔵 Onglets ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _tabPill(
                        icon: Icons.grid_view,
                        label: 'Profil',
                        active: true,
                        onTap: () {}, // déjà ici
                      ),
                      const SizedBox(width: 8),
                      _tabPill(
                        icon: Icons.image,
                        label: 'Albums',
                        active: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfileAlbumsPage()),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _tabPill(
                        icon: Icons.movie,
                        label: 'Réels',
                        active: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const MyReelsPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // --- 🔵 Publications ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                  child: Text(
                    "Mes publications",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),

              if (_pubsLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: ZuaLoaderMini()),
                  ),
                )
              else if (_pubsError)
                SliverToBoxAdapter(
                  child: _emptyCard(
                      "Impossible de charger les publications pour l’instant."),
                )
              else if (_publications.isEmpty)
                SliverToBoxAdapter(
                  child: _emptyCard("Aucune publication pour le moment."),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final pub = _publications[index];
                      return PublicationCard(
                        key: ValueKey(pub['id']),
                        publication: pub,
                        authedDio: _authedDio,
                        onRefresh: () {},
                        isFromProfile: true,
                      );
                    },
                    childCount: _publications.length,
                  ),
                ),
            ],
          ),
        ),

        // ✅ Navigation dans le Scaffold (correctement placée)
        bottomNavigationBar: BottomNav(
          currentIndex: 2,
          unreadNotifications: unreadNotifications,
          unreadMessages: unreadMessages,
        ),
      ),
    );
  }

  // ---------------- Small UI parts ----------------

  Widget _emptyCard(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.info, color: Colors.grey),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, String value) {
    return Chip(
      avatar: Icon(icon, size: 18, color: Colors.white),
      label: Text(
        '$value $label',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: _primary,
    );
  }

  Widget _infoGrid(List<Widget> children) {
    // Grille fluide 3 par ligne
    return LayoutBuilder(
      builder: (ctx, cons) {
        final w = cons.maxWidth;
        final itemW = (w - 16) / 3; // marge approx
        return Wrap(
          runSpacing: 8,
          spacing: 8,
          children: children
              .map(
                (c) => ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: 120,
                    maxWidth: itemW.clamp(120, 220),
                  ),
                  child: c,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _infoItem(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _primary, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text.isEmpty ? '—' : text,
              softWrap: true,
              maxLines: 3,
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabPill({
    required IconData icon,
    required String label,
    bool active = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _primary : Theme.of(context).cardColor,
          border: Border.all(
            color: active ? _primary : Theme.of(context).dividerColor,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: active ? Colors.white : Colors.black87),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: active
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Publications (GRILLE 1:1) ----------------

  // Rendu d’une TUÎLE carrée d’une publication (visuel only)
  Widget _publicationTile(Map<String, dynamic> p) {
    final auteur = (p['auteur'] ?? {}) as Map;
    final photoAuteur = _url(
      auteur['photo'],
      'https://zuachat.com/assets/default-avatar.png',
    );
    final auteurNom = _s(
      auteur['nom'] ??
          [
            auteur['prenom'],
            auteur['nom'],
            auteur['postnom'],
          ].where((e) => (e ?? '').toString().isNotEmpty).join(' '),
      'Utilisateur',
    );

    final texte = _s(p['texte']);
    final createdAt = _s(p['created_at']);
    final bgColorHex = _s(p['background_color']);
    Color? bgColor;
    if (bgColorHex.isNotEmpty) {
      final h = bgColorHex.replaceAll('#', '').trim();
      if (h.length == 6 || h.length == 8) {
        try {
          final value = int.parse(h.length == 6 ? 'FF$h' : h, radix: 16);
          bgColor = Color(value);
        } catch (_) {}
      }
    }

    // fichiers
    List fichiers = [];
    final raw = p['fichiers'];
    if (raw is List) {
      fichiers = raw;
    } else if (raw is String && raw.trim().isNotEmpty) {
      // Ne pas dépendre d'une méthode util inconnue
      if (raw.contains('[') && raw.contains(']')) {
        // tentative simple: split sur ',' et nettoyage
        final cleaned = raw
            .replaceAll('[', '')
            .replaceAll(']', '')
            .split(',')
            .map((e) => e.trim().replaceAll('"', '').replaceAll("'", ''))
            .where((e) => e.isNotEmpty)
            .toList();
        fichiers = cleaned;
      } else {
        fichiers = [raw.trim()];
      }
    }

    final hasMedia = fichiers.isNotEmpty;
    final thumb = hasMedia
        ? _url(
            fichiers.first,
            'https://zuachat.com/assets/placeholder.jpg',
          )
        : '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Media ou fond texte
          if (hasMedia && !thumb.toLowerCase().endsWith('.mp4'))
            CachedNetworkImage(
              imageUrl: thumb,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.black12),
              errorWidget: (_, __, ___) =>
                  const ColoredBox(color: Colors.black12),
            )
          else if (hasMedia && thumb.toLowerCase().endsWith('.mp4'))
            Container(
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Icon(Icons.play_circle_outline, size: 48),
            )
          else
            Container(
              color: bgColor ?? Theme.of(context).cardColor,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(10),
              child: Text(
                texte.isEmpty ? 'Publication' : texte,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: bgColor != null ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // Bandeau info auteur en haut (léger)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black54, Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundImage: CachedNetworkImageProvider(photoAuteur),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      auteurNom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Date en bas-droit
          if (createdAt.isNotEmpty)
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  createdAt.split(' ').first,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
