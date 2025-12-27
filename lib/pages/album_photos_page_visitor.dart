// lib/pages/album_photos_page_visitor.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import '../api/albums_api.dart';
import '../widgets/zua_loader.dart';

class AlbumPhotosPageVisitor extends StatefulWidget {
  final int userId;
  final String type; // profil, cover, all, custom
  final int? albumId;
  final String? albumName;

  const AlbumPhotosPageVisitor({
    super.key,
    required this.userId,
    required this.type,
    this.albumId,
    this.albumName,
  });

  @override
  State<AlbumPhotosPageVisitor> createState() => _AlbumPhotosPageVisitorState();
}

class _AlbumPhotosPageVisitorState extends State<AlbumPhotosPageVisitor> {
  bool _loading = true;
  bool _error = false;
  List<String> _photos = [];

  static const Color red = Color(0xFFFF0000);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
      _photos = [];
    });

    try {
      late Map<String, dynamic> res;

      if (widget.type == "profil") {
        res = await AlbumsApi.fetchProfilePhotosForUser(widget.userId);
      } else if (widget.type == "cover") {
        res = await AlbumsApi.fetchCoverPhotosForUser(widget.userId);
      } else if (widget.type == "all") {
        res = await AlbumsApi.fetchAllPhotosForUser(widget.userId);
      } else {
        res = await AlbumsApi.fetchUserCustomAlbumPhotos(
            widget.userId, widget.albumId!);
      }

      if (res["success"] == true) {
        _photos = List<String>.from(res["photos"] ?? []);
      } else {
        _error = true;
      }
    } catch (_) {
      _error = true;
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _download(String url) async {
    try {
      final r = await Dio()
          .get(url, options: Options(responseType: ResponseType.bytes));

      final data = Uint8List.fromList(r.data);

      await ImageGallerySaverPlus.saveImage(
        data,
        name: "zuachat_${DateTime.now().millisecondsSinceEpoch}",
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image enregistrée 🎉")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erreur : $e")));
    }
  }

  void _openViewer(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: url,
                  placeholder: (_, __) =>
                      const Center(child: ZuaLoader(looping: true)),
                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image,
                      size: 48, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.download, color: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                  _download(url);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == "custom"
        ? (widget.albumName ?? "Album")
        : {
              "profil": "Photos de profil",
              "cover": "Photos de couverture",
              "all": "Photos",
            }[widget.type] ??
            "Photos";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: red, // 🔴 fond rouge
        elevation: 1,

        // ← flèche de retour blanche
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),

        // texte du titre blanc
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),

        title: Text(title),
      ),
      body: _loading
          ? const Center(child: ZuaLoader(looping: true))
          : _error
              ? Center(
                  child: TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Réessayer"),
                  ),
                )
              : _photos.isEmpty
                  ? const Center(child: Text("Aucune photo"))
                  : GridView.builder(
                      padding: const EdgeInsets.all(10),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _photos.length,
                      itemBuilder: (_, i) {
                        final url = _photos[i];

                        return GestureDetector(
                          onTap: () => _openViewer(url),
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: Colors.grey[300]),
                            errorWidget: (_, __, ___) => Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.broken_image)),
                          ),
                        );
                      },
                    ),
    );
  }
}
