import 'dart:io';
import 'package:flutter/material.dart';

import '../api/statut_create.dart';
import '../api/statut_upload.dart';

class StoryEditorPage extends StatefulWidget {
  final File mediaFile;
  final bool isVideo;

  const StoryEditorPage({
    super.key,
    required this.mediaFile,
    required this.isVideo,
  });

  @override
  State<StoryEditorPage> createState() => _StoryEditorPageState();
}

class _StoryEditorPageState extends State<StoryEditorPage> {
  static const primary = Color(0xFF1877F2);

  String _caption = '';
  String _visibility = 'public'; // public | friends (tu pourras étendre)
  bool _loading = false;

  Future<void> _editCaption() async {
    final controller = TextEditingController(text: _caption);

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.25,
          maxChildSize: 0.75,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding:
                  EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: ListView(
                controller: scrollCtrl,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  const Center(
                    child: Icon(Icons.drag_handle, color: Colors.white54),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Légende',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Ajoutez une légende à votre statut...',
                      hintStyle: TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black45,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx, controller.text.trim());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Enregistrer la légende',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() => _caption = result);
    }
  }

  Future<void> _chooseVisibility() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String tempVis = _visibility;
        return StatefulBuilder(
          builder: (_, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.drag_handle, color: Colors.white54),
                  const SizedBox(height: 8),
                  const Text(
                    'Visibilité du statut',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RadioListTile<String>(
                    value: 'public',
                    groupValue: tempVis,
                    onChanged: (v) =>
                        setModalState(() => tempVis = v ?? 'public'),
                    activeColor: primary,
                    title: const Text(
                      'Public',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Tout le monde peut voir ce statut',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  RadioListTile<String>(
                    value: 'friends',
                    groupValue: tempVis,
                    onChanged: (v) =>
                        setModalState(() => tempVis = v ?? 'friends'),
                    activeColor: primary,
                    title: const Text(
                      'Amis',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Uniquement vos amis (amis mutuels)',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, tempVis),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Valider',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() => _visibility = result);
    }
  }

  Future<void> _submit() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      // 1️⃣ Upload du média
      final mediaPath = await uploadStatutMedia(widget.mediaFile);

      // 2️⃣ Création du statut
      await apiStatutCreate(
        mediaPath,
        visibility: _visibility,
        caption: _caption,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Statut publié ✅')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1877F2);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 🖼 PREVIEW
            Positioned.fill(
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: widget.isVideo
                        ? Container(
                            color: Colors.black,
                            child: const Center(
                              child: Icon(
                                Icons.videocam,
                                color: Colors.white70,
                                size: 56,
                              ),
                            ),
                          )
                        : Image.file(
                            widget.mediaFile,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ),
            ),

            // 🔝 TOP BAR
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _loading ? null : _editCaption,
                    child: Row(
                      children: [
                        const Icon(Icons.text_fields,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          _caption.isEmpty ? 'Légende' : 'Modifier la légende',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 🔻 BOTTOM CONTROLS
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // ⚙️ Visibilité
                      InkWell(
                        onTap: _loading ? null : _chooseVisibility,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.settings,
                                  color: Colors.white70, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                _visibility == 'public'
                                    ? 'Public'
                                    : 'Amis uniquement',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_caption.isNotEmpty)
                        Expanded(
                          child: Text(
                            _caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // BOUTON AJOUTER STATUT
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Ajouter le statut',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
