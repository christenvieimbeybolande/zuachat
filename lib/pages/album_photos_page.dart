import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import '../api/albums_api.dart';
import '../api/client.dart';

class AlbumPhotosPage extends StatefulWidget {
  final String type; // 'profil','cover','mes_photos','custom'
  final int? albumId;
  final String? albumName;

  const AlbumPhotosPage({
    super.key,
    required this.type,
    this.albumId,
    this.albumName,
  });

  @override
  State<AlbumPhotosPage> createState() => _AlbumPhotosPageState();
}

class _AlbumPhotosPageState extends State<AlbumPhotosPage> {
  bool _loading = true;
  String? _error;

  List<String> _photos = [];
  List<Map<String, dynamic>> _media = [];
  Map<String, Map<String, dynamic>> _mediaByUrl = {};

  static const int maxCustomAlbums = 8;
  static const int defaultAlbums = 3;
  static const Color red = Color(0xFFFF0000);

  @override
  void initState() {
    super.initState();
    _load();
  }

  // LOAD
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _photos.clear();
      _media.clear();
      _mediaByUrl.clear();
    });

    try {
      if (widget.type == 'profil') {
        final res = await AlbumsApi.fetchProfilePhotos();
        if (res['success']) {
          _photos = List<String>.from(res['photos']);
        } else {
          _error = res['message'];
        }
      } else if (widget.type == 'cover') {
        final res = await AlbumsApi.fetchCoverPhotos();
        if (res['success']) {
          _photos = List<String>.from(res['photos']);
        } else {
          _error = res['message'];
        }
      } else if (widget.type == 'mes_photos') {
        final res = await AlbumsApi.fetchAllPhotos();
        if (res['success']) {
          _media = List<Map<String, dynamic>>.from(res['media']);
          for (final m in _media) {
            final url = m['url'] ?? '';
            if (url != '') {
              _photos.add(url);
              _mediaByUrl[url] = m;
            }
          }
        } else {
          _error = res['message'];
        }
      } else if (widget.type == 'custom') {
        final id = widget.albumId;
        if (id == null) {
          _error = "Album invalide";
        } else {
          final res = await AlbumsApi.fetchCustomAlbumPhotos(id);
          if (res['success']) {
            _photos = List<String>.from(res['photos']);
          } else {
            _error = res['message'];
          }
        }
      }
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) setState(() => _loading = false);
  }

  // DOWNLOAD
  Future<void> _download(String url) async {
    try {
      final dio = Dio();
      final resp = await dio.get(url,
          options: Options(responseType: ResponseType.bytes));
      final data = Uint8List.fromList(resp.data);

      final r = await ImageGallerySaverPlus.saveImage(
        data,
        name: "zuachat_${DateTime.now().millisecondsSinceEpoch}",
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                r['isSuccess'] == true ? "Image enregistrée 🎉" : "Échec")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erreur : $e")));
    }
  }

  // DELETE
  Future<void> _deletePhoto(int index) async {
    final url = _photos[index];

    bool allowed = false;

    if (widget.type == 'custom') allowed = true;

    if (widget.type == 'mes_photos') {
      final info = _mediaByUrl[url];
      if (info?['type'] == 'publication') allowed = true;
    }

    if (widget.type == 'profil' || widget.type == 'cover') allowed = true;

    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Suppression non autorisée")),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer"),
        content: const Text("Supprimer cette photo ?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Annuler")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Supprimer")),
        ],
      ),
    );

    if (ok != true) return;

    bool success = false;

    try {
      if (widget.type == 'mes_photos') {
        success = await AlbumsApi.deleteMedia(url);
      } else if (widget.type == 'custom') {
        success = await AlbumsApi.deleteFromAlbum(widget.albumId!, url);
      } else if (widget.type == 'profil') {
        success = await _deleteProfileFile(url);
      } else if (widget.type == 'cover') {
        success = await _deleteCoverFile(url);
      }

      if (success) {
        await AlbumsApi.deleteMedia(url);
      }
    } catch (_) {}

    if (success) {
      setState(() {
        _photos.removeAt(index);
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Photo supprimée")));

      if (_photos.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 200));
        await _load();
      }
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Échec suppression")));
    }
  }

  Future<bool> _deleteProfileFile(String url) async {
    try {
      final dio = await ApiClient.authed();
      final res = await dio.post('/albums_profil.php', data: {'delete': url});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _deleteCoverFile(String url) async {
    try {
      final dio = await ApiClient.authed();
      final res = await dio.post('/albums_cover.php', data: {'delete': url});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // ----------------------- AJOUT AU RACCOURCI -----------------------
  Future<void> _addToRaccourci(String url) async {
    final res = await AlbumsApi.fetchProfileAlbums();
    if (res['success'] != true) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res['message'] ?? "Erreur")));
      return;
    }

    final data = res['data'] as Map<String, dynamic>;
    final custom = List<Map<String, dynamic>>.from(
      data['albums_personnalises'] ?? [],
    );

    final total = defaultAlbums + custom.length;

    showModalBottomSheet(
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      context: context,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Ajouter au raccourci",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (custom.isEmpty) const Text("Aucun album personnalisé"),
                ...custom.map((album) {
                  return ListTile(
                    leading: const Icon(Icons.folder, color: red),
                    title: Text(album['nom']),
                    onTap: () async {
                      Navigator.pop(context);
                      await _attach(album['id'], url);
                    },
                  );
                }),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.create_new_folder),
                  label: const Text("Créer un album"),
                  onPressed: () async {
                    Navigator.pop(context);

                    if (total >= 11) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Limite maximale atteinte (8 albums personnalisés).",
                          ),
                        ),
                      );
                      return;
                    }

                    final name = await _promptAlbumName();
                    if (name != null && name.trim().isNotEmpty) {
                      final r = await AlbumsApi.createAlbum(name.trim());
                      if (r['success']) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Album créé")),
                        );
                        await _load();
                        _addToRaccourci(url);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _attach(int albumId, String url) async {
    try {
      final dio = await ApiClient.authed();
      final r = await dio.post('/photos_albums_actions.php', data: {
        'action': 'attach',
        'album_id': albumId,
        'file_url': url,
      });

      if (r.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ajouté au raccourci")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.data['message'] ?? "Erreur")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erreur : $e")));
    }
  }

  Future<String?> _promptAlbumName() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Nouvel album"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Nom de l'album"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // ----------------------------- BUILD -----------------------------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF18191A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF242526) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subText = isDark ? Colors.white70 : Colors.black54;

    final title = widget.type == 'custom'
        ? (widget.albumName ?? "Album")
        : {
              'profil': "Photos de profil",
              'cover': "Photos de couverture",
              'mes_photos': "Mes photos",
            }[widget.type] ??
            "Photos";

    return Scaffold(
      backgroundColor: bgColor,

      // ================= APPBAR =================
      appBar: AppBar(
        backgroundColor: red,
        foregroundColor: Colors.white, // 🔥 retour + icônes blancs
        elevation: 1,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      // ================= BODY =================
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: TextStyle(color: textColor),
                  ),
                )
              : _photos.isEmpty
                  ? Center(
                      child: Text(
                        "Aucune photo",
                        style: TextStyle(color: subText),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _photos.length,
                      itemBuilder: (_, index) {
                        final url = _photos[index];
                        String type = '';

                        if (widget.type == 'mes_photos') {
                          final info = _mediaByUrl[url];
                          type = info?['type'] ?? '';
                        }

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FullPhotoView(
                                  url: url,
                                  parentType: widget.type,
                                  mesPhotoType: type,
                                  onDownload: () => _download(url),
                                  onDelete: () => _deletePhoto(index),
                                  onAddToRaccourci: () => _addToRaccourci(url),
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: cardBg),
                              errorWidget: (_, __, ___) => Container(
                                color: cardBg,
                                child: const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

// =================================================================
// -------------------------- FULL PHOTO VIEW ------------------------
// =================================================================

class FullPhotoView extends StatelessWidget {
  final String url;
  final String parentType;
  final String? mesPhotoType;
  final VoidCallback onDownload;
  final Future<void> Function() onDelete;
  final VoidCallback onAddToRaccourci;

  static const Color red = Color(0xFFFF0000);

  const FullPhotoView({
    super.key,
    required this.url,
    required this.parentType,
    this.mesPhotoType,
    required this.onDownload,
    required this.onDelete,
    required this.onAddToRaccourci,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> actions = [];

    void close(VoidCallback fn) {
      Navigator.pop(context);
      fn();
    }

    // Toujours disponible
    actions.add(
      ListTile(
        leading: const Icon(Icons.download, color: red),
        title: const Text("Télécharger", style: TextStyle(color: Colors.white)),
        onTap: () => close(onDownload),
      ),
    );

    if (parentType == 'profil' || parentType == 'cover') {
      actions.add(
        ListTile(
          leading: const Icon(Icons.delete, color: red),
          title: const Text("Supprimer", style: TextStyle(color: Colors.white)),
          onTap: () async {
            Navigator.pop(context);
            Navigator.pop(context);
            await onDelete();
          },
        ),
      );
    } else if (parentType == 'mes_photos') {
      final t = mesPhotoType ?? '';
      if (t == 'publication') {
        actions.add(
          ListTile(
            leading: const Icon(Icons.delete, color: red),
            title:
                const Text("Supprimer", style: TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(context);
              Navigator.pop(context);
              await onDelete();
            },
          ),
        );

        actions.add(
          ListTile(
            leading: const Icon(Icons.bookmark_add, color: red),
            title: const Text("Ajouter au raccourci",
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              onAddToRaccourci();
            },
          ),
        );
      } else {
        actions.add(
          ListTile(
            leading: const Icon(Icons.bookmark_add, color: red),
            title: const Text("Ajouter au raccourci",
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              onAddToRaccourci();
            },
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.black87,
                builder: (_) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: actions,
                  ),
                ),
              );
            },
          )
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: url,
            placeholder: (_, __) => Container(color: Colors.grey[900]),
            errorWidget: (_, __, ___) =>
                const Icon(Icons.broken_image, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
