import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:video_compress/video_compress.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../widgets/zua_loader_mini.dart';
import '../api/add_publication.dart';

enum PublicationMode { images, reel, text }

class AddPublicationPage extends StatefulWidget {
  const AddPublicationPage({super.key});

  @override
  State<AddPublicationPage> createState() => _AddPublicationPageState();
}

class _AddPublicationPageState extends State<AddPublicationPage> {
  final TextEditingController _texteController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  PublicationMode _mode = PublicationMode.images;

  List<File> _selectedImages = [];
  File? _selectedVideo;
  File? _thumbnailFile;

  VideoPlayerController? _videoController;

  bool _loading = false;
  bool _compressing = false;
  double _compressionProgress = 0.0;
  double _uploadProgress = 0.0;

  String _visibility = 'public';
  Color? _backgroundColor;

  bool _useCustomThumbnail =
      false; // Nouveau toggle pour choisir un thumbnail personnalisé

  static const int maxImages = 50;
  static const int maxTextCharsForBackground = 80;
  static const Duration maxReelDuration = Duration(minutes: 30);
  static const int maxReelBytes = 500 * 1024 * 1024;

  final List<Color> _colors = [
    Colors.transparent,
    Color(0xFFFF0000),
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.purpleAccent,
    Colors.orangeAccent,
    Colors.tealAccent,
    Colors.yellowAccent,
  ];

  @override
  void dispose() {
    _texteController.dispose();
    _videoController?.dispose();
    VideoCompress.cancelCompression();
    VideoCompress.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  // -----------------------------------
  // PICK IMAGES
  // -----------------------------------
  Future<void> _pickImages() async {
    try {
      final files = await _picker.pickMultiImage();
      if (files == null) return;

      final imgs = files.map((x) => File(x.path)).toList();

      if (_selectedImages.length + imgs.length > maxImages) {
        Fluttertoast.showToast(msg: "Max $maxImages images.");
        return;
      }

      setState(() => _selectedImages.addAll(imgs));
    } catch (e) {
      Fluttertoast.showToast(msg: "Erreur images : $e");
    }
  }

  // -----------------------------------
  // PICK VIDEO + THUMBNAIL
  // -----------------------------------
  Future<void> _pickVideo() async {
    try {
      final file = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: maxReelDuration,
      );
      if (!mounted || file == null) return;

      final f = File(file.path);

      if ((await f.length()) > maxReelBytes) {
        Fluttertoast.showToast(msg: "Vidéo > 500MB !");
        return;
      }

      setState(() => _selectedVideo = f);
      await _initializeVideoPreview();

      // 🔥 GÉNÉRATION MINIATURE flutter si le toggle est OFF
      if (!_useCustomThumbnail) {
        final uint8list = await VideoThumbnail.thumbnailData(
          video: f.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 512,
          quality: 75,
        );

        if (uint8list != null) {
          final thumb = File("${f.path}_thumb.jpg");
          await thumb.writeAsBytes(uint8list);
          _thumbnailFile = thumb;
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Erreur vidéo : $e");
    }
  }

  Future<void> _initializeVideoPreview() async {
    if (_selectedVideo == null) return;

    _videoController?.dispose();
    _videoController = VideoPlayerController.file(_selectedVideo!);

    await _videoController!.initialize();
    setState(() {});
  }

  // -----------------------------------
  // CHOISIR UN THUMBNAIL PERSONNALISÉ
  // -----------------------------------
  Future<void> _pickCustomThumbnail() async {
    try {
      final img = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (img == null) return;

      setState(() {
        _thumbnailFile = File(img.path);
      });
    } catch (e) {
      Fluttertoast.showToast(msg: "Erreur thumbnail : $e");
    }
  }

  // -----------------------------------
  // SUBMIT PUBLICATION
  // -----------------------------------
  Future<void> _submit() async {
    final texte = _texteController.text.trim();

    if (_mode == PublicationMode.images && _selectedImages.isEmpty) {
      Fluttertoast.showToast(msg: "Ajoute une image.");
      return;
    }

    if (_mode == PublicationMode.reel && _selectedVideo == null) {
      Fluttertoast.showToast(msg: "Ajoute une vidéo.");
      return;
    }

    if (_mode == PublicationMode.text && texte.isEmpty) {
      Fluttertoast.showToast(msg: "Écris quelque chose.");
      return;
    }

    File? finalVideo;

    // -----------------------------------
    // 🔥 FIX : Reset compression avant nouveau compress
    // -----------------------------------
    VideoCompress.cancelCompression();
    await VideoCompress.deleteAllCache();

    // -----------------------------------
    // 🔥 COMPRESSION VIDÉO FIABLE
    // -----------------------------------
    if (_mode == PublicationMode.reel) {
      setState(() {
        _compressing = true;
        _compressionProgress = 0;
      });

      // Nettoyage avant nouvelle compression
      VideoCompress.cancelCompression();
      await VideoCompress.deleteAllCache();

      // 🔥 LECTURE DU PROGRÈS
      final subscription =
          VideoCompress.compressProgress$.subscribe((progress) {
        if (mounted) {
          setState(() => _compressionProgress = progress.toDouble());
        }
      });

      final info = await VideoCompress.compressVideo(
        _selectedVideo!.path,
        quality: VideoQuality.MediumQuality,
        includeAudio: true,
        deleteOrigin: false,
      );

      // FIN progres → arrêter l'écoute
      subscription.unsubscribe();

      if (info == null || info.file == null) {
        Fluttertoast.showToast(msg: "Erreur compression vidéo");
        setState(() => _compressing = false);
        return;
      }

      finalVideo = info.file;

      setState(() => _compressing = false);
    }

    // -----------------------------------
    // 🔥 UPLOAD
    // -----------------------------------
    setState(() {
      _loading = true;
      _uploadProgress = 0;
    });

    String bgHex = "";
    if (_backgroundColor != null && _backgroundColor != Colors.transparent) {
      bgHex = "#${_backgroundColor!.value.toRadixString(16).substring(2)}";
    }

    // fichiers envoyés
    List<File>? uploadFiles;

    if (_mode == PublicationMode.images) {
      uploadFiles = _selectedImages;
    } else if (_mode == PublicationMode.reel) {
      uploadFiles = [finalVideo!];
      if (_thumbnailFile != null) uploadFiles.add(_thumbnailFile!);
    }

    try {
      await apiAddPublication(
        texte: texte,
        visibility: _visibility,
        backgroundColorHex: bgHex,
        fichiers: uploadFiles,
        typePublication: _mode == PublicationMode.images
            ? "normal"
            : _mode == PublicationMode.reel
                ? "reel"
                : "text",
        onSendProgress: (sent, total) {
          if (!mounted) return;
          setState(() => _uploadProgress = sent / total);
        },
      );

      Fluttertoast.showToast(msg: "Publication envoyée !");
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      Fluttertoast.showToast(msg: "Erreur : $e");
    } finally {
      WakelockPlus.disable();
      setState(() {
        _loading = false;
        _compressing = false;
      });
    }
  }

  // -----------------------------------
  // UI SCREENS
  // -----------------------------------
  @override
  Widget build(BuildContext context) {
    if (_compressing) {
      return _progressScreen("Compression…", _compressionProgress);
    }

    if (_loading) {
      return _progressScreen("Envoi…", _uploadProgress * 100);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF0000),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Nouvelle publication",
            style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _submit,
            child: const Text("Publier", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _modeSelector(),
            const SizedBox(height: 16),
            if (_mode == PublicationMode.images) _imagesMode(),
            if (_mode == PublicationMode.reel) _reelMode(),
            if (_mode == PublicationMode.text) _textMode(),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text("Visibilité : "),
                DropdownButton(
                  value: _visibility,
                  items: const [
                    DropdownMenuItem(value: "public", child: Text("🌍 Public")),
                    DropdownMenuItem(value: "friends", child: Text("👥 Amis")),
                    DropdownMenuItem(value: "me", child: Text("🔒 Moi")),
                  ],
                  onChanged: (v) => setState(() => _visibility = v!),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  // -----------------------------------
  Widget _progressScreen(String text, double progress) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ZuaLoaderMini(),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text("${progress.toStringAsFixed(0)} %"),
        ]),
      ),
    );
  }

  // -----------------------------------
  Widget _modeSelector() {
    Widget btn(PublicationMode m, IconData icon, String label) {
      final active = _mode == m;
      return GestureDetector(
        onTap: () => setState(() => _mode = m),
        child: Column(
          children: [
            CircleAvatar(
              radius: active ? 36 : 30,
              backgroundColor: active ? Colors.red : Colors.grey.shade300,
              child: Icon(icon, color: active ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 6),
            Text(label)
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        btn(PublicationMode.images, Icons.photo, "Images"),
        btn(PublicationMode.reel, Icons.video_file, "Reel"),
        btn(PublicationMode.text, Icons.text_fields, "Texte"),
      ],
    );
  }

  // -----------------------------------
  Widget _imagesMode() {
    return Column(children: [
      TextField(
        controller: _texteController,
        decoration: const InputDecoration(hintText: "Légende..."),
      ),
      const SizedBox(height: 12),
      Wrap(
        children: _selectedImages.map((img) {
          return Stack(children: [
            Container(
              margin: const EdgeInsets.all(4),
              child:
                  Image.file(img, width: 100, height: 100, fit: BoxFit.cover),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => setState(() => _selectedImages.remove(img)),
                child: const CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            )
          ]);
        }).toList(),
      ),
      OutlinedButton.icon(
        onPressed: _pickImages,
        icon: const Icon(Icons.photo_library),
        label: const Text("Ajouter des images"),
      )
    ]);
  }

  // -----------------------------------
  Widget _reelMode() {
    return Column(children: [
      TextField(
        controller: _texteController,
        decoration: const InputDecoration(hintText: "Légende du reel..."),
      ),
      const SizedBox(height: 12),
      if (_selectedVideo != null) _videoPreview(),
      OutlinedButton.icon(
        onPressed: _pickVideo,
        icon: const Icon(Icons.video_library),
        label: const Text("Choisir une vidéo"),
      ),
      SwitchListTile(
        title: const Text("Choisir une photo de couverture"),
        value: _useCustomThumbnail,
        onChanged: (v) {
          setState(() {
            _useCustomThumbnail = v;
            if (!v) _thumbnailFile = null; // Reset thumbnail
          });
        },
      ),
      if (_useCustomThumbnail)
        OutlinedButton.icon(
          onPressed: _pickCustomThumbnail,
          icon: const Icon(Icons.image),
          label: const Text("Choisir la couverture"),
        ),
      if (_thumbnailFile != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _thumbnailFile!,
              width: 180,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
        ),
    ]);
  }

  Widget _videoPreview() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return Container(
        height: 200,
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Text("Aperçu vidéo indisponible"),
      );
    }

    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: Stack(children: [
        VideoPlayer(_videoController!),
        Center(
          child: IconButton(
            icon: Icon(
              _videoController!.value.isPlaying
                  ? Icons.pause_circle
                  : Icons.play_circle,
              size: 50,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                if (_videoController!.value.isPlaying) {
                  _videoController!.pause();
                } else {
                  _videoController!.play();
                }
              });
            },
          ),
        )
      ]),
    );
  }

  // -----------------------------------
  Widget _textMode() {
    final txt = _texteController.text.trim();
    final useBg = txt.length <= maxTextCharsForBackground;

    return Column(children: [
      TextField(
        controller: _texteController,
        decoration: InputDecoration(
            hintText: "Texte (<= $maxTextCharsForBackground caractères)"),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      _colorPicker(),
      const SizedBox(height: 12),
      Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          color: useBg ? _backgroundColor : Colors.transparent,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          txt,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: (useBg && _backgroundColor != null)
                ? Colors.white
                : Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      )
    ]);
  }

  Widget _colorPicker() {
    return SizedBox(
      height: 55,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _colors.map((c) {
          final active = c == _backgroundColor;
          return GestureDetector(
            onTap: () => setState(() => _backgroundColor = active ? null : c),
            child: Container(
              width: 45,
              height: 45,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: active ? Colors.red : Colors.grey, width: 2),
              ),
              child:
                  active ? const Icon(Icons.check, color: Colors.white) : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}
