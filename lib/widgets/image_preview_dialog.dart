import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:dio/dio.dart';

class ImagePreviewDialog extends StatefulWidget {
  final String imageUrl;
  final String type; // 'profile', 'cover' ou 'publication'
  final VoidCallback? onDelete;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onMessage;
  final Future<Dio> Function()? authedDio;
  final bool canEdit; // ✅ ajouté

  const ImagePreviewDialog({
    super.key,
    required this.imageUrl,
    required this.type,
    this.onDelete,
    this.onChanged,
    this.onMessage,
    this.authedDio,
    this.canEdit = true,
  });

  @override
  State<ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<ImagePreviewDialog> {
  bool _updating = false;

  Future<void> _showMessage(String text,
      {Color color = Colors.green, bool propagate = true}) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    if (propagate && widget.onMessage != null) widget.onMessage!(text);
  }

  // 🟦 Changer photo (selon type)
  Future<void> _changePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _updating = true);

    try {
      final dio = await widget.authedDio!();
      final formData = FormData();

      // ✅ selon le type
      String endpoint = '';
      if (widget.type == 'profile') {
        formData.fields.add(MapEntry('type', 'profile'));
        formData.files.add(MapEntry(
            'photo', await MultipartFile.fromFile(picked.path)));
        endpoint =
            'https://zuachat.com/api/update_photo.php';
      } else if (widget.type == 'cover') {
        formData.fields.add(MapEntry('type', 'cover'));
        formData.files.add(MapEntry(
            'couverture', await MultipartFile.fromFile(picked.path)));
        endpoint =
            'https://zuachat.com/api/update_cover.php';
      } else {
        formData.fields.add(MapEntry('type', 'publication'));
        formData.files.add(MapEntry(
            'photo', await MultipartFile.fromFile(picked.path)));
        endpoint =
            'https://zuachat.com/api/update_photo_publication.php';
      }

      final res = await dio.post(endpoint, data: formData);

      if (res.data['success'] == true) {
        widget.onChanged?.call(res.data['url']);
        Navigator.pop(context);
        await _showMessage(res.data['message'] ?? 'Photo remplacée ');
      } else {
        await _showMessage(res.data['message'] ?? 'Erreur lors du changement ',
            color: Colors.redAccent);
      }
    } catch (e) {
      await _showMessage('Erreur réseau ⚠️ : $e', color: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  // 🟨 Enregistrer dans galerie
  Future<void> _saveToGallery() async {
    try {
      final dio = Dio();
      final response = await dio.get(widget.imageUrl,
          options: Options(responseType: ResponseType.bytes));

      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(response.data),
        name: 'zuachat_${widget.type}_${DateTime.now().millisecondsSinceEpoch}',
        quality: 100,
      );

      if (result['isSuccess'] == true) {
        await _showMessage('📸 Image enregistrée avec succès ');
      } else {
        await _showMessage(' Échec de l’enregistrement dans la galerie.',
            color: Colors.redAccent);
      }
    } catch (e) {
      await _showMessage('Erreur enregistrement : $e',
          color: Colors.redAccent);
    }
  }

  // 🟥 Supprimer photo avec confirmation
  Future<void> _deletePhoto() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Voulez-vous vraiment supprimer cette image ?'),
        actions: [
          TextButton(
            child: const Text('Annuler'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Supprimer'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _updating = true);
    try {
      final dio = await widget.authedDio!();
      final formData = FormData.fromMap({'type': widget.type});
      final res = await dio.post(
        'https://zuachat.com/api/delete_image.php',
        data: formData,
      );

      if (res.data['success'] == true) {
        widget.onChanged?.call(res.data['url']);
        widget.onDelete?.call();
        Navigator.pop(context);
        await _showMessage(res.data['message'] ?? 'Photo supprimée 🗑️');
      } else {
        await _showMessage(res.data['message'] ?? 'Erreur suppression ❌',
            color: Colors.redAccent);
      }
    } catch (e) {
      await _showMessage('Erreur suppression ⚠️ : $e', color: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isProfileOrCover =
        widget.type == 'profile' || widget.type == 'cover';

    return Dialog.fullscreen(
      backgroundColor: Colors.black.withOpacity(0.95),
      child: Stack(
        children: [
          // 🖼️ Image principale
          Center(
            child: InteractiveViewer(
              child: Image.network(
                widget.imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 80,
                ),
              ),
            ),
          ),

          // 📜 Menu d’actions dynamiques
          Positioned(
            top: 20,
            right: 20,
            child: PopupMenuButton<String>(
              color: Colors.white,
              icon: _updating
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const Icon(Icons.more_vert, color: Colors.white, size: 30),
              onSelected: (val) async {
                if (val == 'download') {
                  await _saveToGallery();
                } else if (val == 'delete') {
                  await _deletePhoto();
                } else if (val == 'change') {
                  await _changePhoto();
                }
              },
              itemBuilder: (_) {
                final List<PopupMenuEntry<String>> items = [
                  const PopupMenuItem(
                    value: 'download',
                    child: Row(
                      children: [
                        Icon(Icons.download, color: Colors.black54),
                        SizedBox(width: 8),
                        Text('Enregistrer'),
                      ],
                    ),
                  ),
                ];

                if (widget.canEdit) {
                  if (isProfileOrCover) {
                    // ✅ Profil / couverture → changer + supprimer
                    items.addAll([
                      const PopupMenuItem(
                        value: 'change',
                        child: Row(
                          children: [
                            Icon(Icons.camera_alt, color: Colors.blueAccent),
                            SizedBox(width: 8),
                            Text('Changer la photo'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Supprimer'),
                          ],
                        ),
                      ),
                    ]);
                  } else {
                    // ✅ Publication → changer + supprimer
                    items.addAll([
                      const PopupMenuItem(
                        value: 'change',
                        child: Row(
                          children: [
                            Icon(Icons.camera_alt, color: Colors.blueAccent),
                            SizedBox(width: 8),
                            Text('Changer la photo'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Supprimer'),
                          ],
                        ),
                      ),
                    ]);
                  }
                }

                return items;
              },
            ),
          ),

          // 🔙 Bouton retour
          Positioned(
            top: 20,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
