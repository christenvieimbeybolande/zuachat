import 'package:flutter/material.dart';
import '../api/albums_api.dart';
import '../widgets/album_card.dart';
import 'album_photos_page.dart';

class ProfileAlbumsPage extends StatefulWidget {
  const ProfileAlbumsPage({super.key});

  @override
  State<ProfileAlbumsPage> createState() => _ProfileAlbumsPageState();
}

class _ProfileAlbumsPageState extends State<ProfileAlbumsPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;

  Map<String, dynamic> profil = {};
  Map<String, dynamic> cover = {};
  Map<String, dynamic> mesPhotos = {};
  List<dynamic> albumsPerso = [];

  static const Color red = Color(0xFFFF0000);
  static const String defaultCover =
      "https://zuachat.com/assets/dossiervide.jpg";

  // Animation controller (pour le bouton créer)
  late AnimationController anim;

  @override
  void initState() {
    super.initState();
    anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 0.8,
      upperBound: 1.0,
    );
    anim.forward();
    _load();
  }

  @override
  void dispose() {
    anim.dispose();
    super.dispose();
  }

  // ====================== CHARGEMENT ======================
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await AlbumsApi.fetchProfileAlbums();

    if (res['success'] == true) {
      final data = Map<String, dynamic>.from(res['data'] ?? {});

      profil = Map<String, dynamic>.from(data['profil'] ?? {});
      cover = Map<String, dynamic>.from(data['cover'] ?? {});
      mesPhotos = Map<String, dynamic>.from(data['mes_photos'] ?? {});
      albumsPerso = List.from(data['albums_personnalises'] ?? []);
    } else {
      _error = res['message'];
    }

    if (mounted) setState(() => _loading = false);
  }

  // ====================== CRÉER ALBUM ======================
  Future<void> _createAlbum() async {
    if (albumsPerso.length >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Limite maximale atteinte (8 albums personnalisés)."),
        ),
      );
      return;
    }

    final name = await _prompt("Nom de l'album");
    if (name == null || name.trim().isEmpty) return;

    final res = await AlbumsApi.createAlbum(name.trim());
    if (res['success'] == true) {
      await _load();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Album créé")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? "Erreur")),
      );
    }
  }

  // ====================== RENOMMER ======================
  Future<void> _renameAlbum(int id, String oldName) async {
    final name = await _prompt("Renommer l'album", initial: oldName);
    if (name == null || name.trim().isEmpty) return;

    final res = await AlbumsApi.renameAlbum(id, name.trim());
    if (res['success']) await _load();
  }

  // ====================== SUPPRIMER ======================
  Future<void> _deleteAlbum(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer"),
        content: const Text("Supprimer définitivement cet album ?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Supprimer")),
        ],
      ),
    );

    if (ok != true) return;

    final res = await AlbumsApi.deleteAlbum(id);
    if (res['success']) await _load();
  }

  // ====================== OUVRIR ALBUM ======================
  void _openAlbum(String type, {int? albumId, String? albumName}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlbumPhotosPage(
          type: type,
          albumId: albumId,
          albumName: albumName,
        ),
      ),
    );

    _load();
  }

  // ====================== POPUP NOM ======================
  Future<String?> _prompt(String title, {String initial = ""}) async {
    final ctrl = TextEditingController(text: initial);

    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Nom"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler")),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text("OK")),
        ],
      ),
    );
  }

  // BOUTON ANIMÉ "Créer un album"
  Widget _buildCreateAlbumButton() {
    return ScaleTransition(
      scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
      child: GestureDetector(
        onTap: _createAlbum,
        child: Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.create_new_folder, color: red, size: 40),
              SizedBox(height: 8),
              Text(
                "Créer un album",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================================
  // ========================= BUILD =========================
  // ========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes Albums"),
        foregroundColor: const Color.fromARGB(255, 255, 255, 255),
        backgroundColor: const Color.fromARGB(255, 255, 0, 0),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createAlbum,
            color: const Color.fromARGB(255, 255, 255, 255),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  const SizedBox(height: 12),

                  // -----------------------------------
                  // ALBUMS PAR DÉFAUT + bouton créer
                  // -----------------------------------
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 0.78,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      children: [
                        AlbumCard(
                          title: "Profil",
                          imageUrl: profil['cover'] ?? defaultCover,
                          count: profil['count'] ?? 0,
                          onTap: () => _openAlbum("profil"),
                        ),
                        AlbumCard(
                          title: "Couverture",
                          imageUrl: cover['cover'] ?? defaultCover,
                          count: cover['count'] ?? 0,
                          onTap: () => _openAlbum("cover"),
                        ),
                        AlbumCard(
                          title: "Mes photos",
                          imageUrl: mesPhotos['cover'] ?? defaultCover,
                          count: mesPhotos['count'] ?? 0,
                          onTap: () => _openAlbum("mes_photos"),
                        ),

                        // 🔥 BOUTON CRÉER UN ALBUM ICI
                        if (albumsPerso.length < 8) _buildCreateAlbumButton(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // -----------------------------------
                  // ALBUMS PERSONNALISÉS
                  // -----------------------------------
                  if (albumsPerso.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        "Albums personnalisés",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: albumsPerso.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.78,
                      ),
                      itemBuilder: (_, i) {
                        final a = Map<String, dynamic>.from(albumsPerso[i]);

                        return AlbumCard(
                          title: a['nom'],
                          imageUrl: a['couverture'] ?? defaultCover,
                          count: a['total_photos'] ?? 0,
                          onTap: () => _openAlbum(
                            "custom",
                            albumId: a['id'],
                            albumName: a['nom'],
                          ),
                          onMenu: () => _showAlbumMenu(a['id'], a['nom']),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ====================== MENU ALBUM ======================
  void _showAlbumMenu(int id, String name) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: red),
              title: const Text("Renommer"),
              onTap: () {
                Navigator.pop(context);
                _renameAlbum(id, name);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: red),
              title: const Text("Supprimer"),
              onTap: () {
                Navigator.pop(context);
                _deleteAlbum(id);
              },
            )
          ],
        ),
      ),
    );
  }
}
