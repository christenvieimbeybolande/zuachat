import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:dio/dio.dart';

import '../api/client.dart';
import 'saved_folder_page.dart';

class SavedPage extends StatefulWidget {
  const SavedPage({super.key});

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  static const Color primary = Color(0xFFFF0000);

  bool loading = true;
  List<Map<String, dynamic>> folders = [];

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  // =========================================================
  // 📦 Charger dossiers
  // =========================================================
  Future<void> _loadFolders() async {
    setState(() => loading = true);
    try {
      final dio = await ApiClient.authed();
      final res = await dio.get('/saved_folders.php');

      if (res.data['success'] == true && res.data['data'] is List) {
        setState(() {
          folders = List<Map<String, dynamic>>.from(res.data['data']);
          loading = false;
        });
      } else {
        Fluttertoast.showToast(
          msg: res.data['message'] ?? 'Erreur de chargement',
        );
        setState(() => loading = false);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Erreur réseau : $e");
      setState(() => loading = false);
    }
  }

  // =========================================================
  // ➕ Créer dossier
  // =========================================================
  Future<void> _createFolder() async {
    final controller = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Nouveau dossier"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Nom du dossier"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: primary),
            child: const Text("Créer"),
          ),
        ],
      ),
    );

    if (created == true && controller.text.trim().isNotEmpty) {
      try {
        final dio = await ApiClient.authed();
        final res = await dio.post(
          '/create_saved_folder.php',
          data: {'nom': controller.text.trim()},
        );

        if (res.data['success'] == true) {
          Fluttertoast.showToast(msg: "📁 Dossier créé !");
          _loadFolders();
        } else {
          Fluttertoast.showToast(
            msg: res.data['message'] ?? "Erreur création dossier",
          );
        }
      } catch (e) {
        Fluttertoast.showToast(msg: "Erreur : $e");
      }
    }
  }

  // =========================================================
  // ✏️ Renommer dossier
  // =========================================================
  Future<void> _renameFolder(Map<String, dynamic> folder) async {
    final controller = TextEditingController(text: folder['nom']);

    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Renommer le dossier"),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: primary),
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );

    if (updated == true && controller.text.trim().isNotEmpty) {
      try {
        final dio = await ApiClient.authed();
        final res = await dio.post(
          '/rename_saved_folder.php',
          data: {
            'id': folder['id'],
            'nom': controller.text.trim(),
          },
        );

        if (res.data['success'] == true) {
          Fluttertoast.showToast(msg: "✅ Nom modifié !");
          _loadFolders();
        }
      } catch (e) {
        Fluttertoast.showToast(msg: "Erreur : $e");
      }
    }
  }

  // =========================================================
  // 🗑 Supprimer dossier
  // =========================================================
  Future<void> _deleteFolder(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer le dossier"),
        content: const Text("Voulez-vous vraiment supprimer ce dossier ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final dio = await ApiClient.authed();
        final res =
            await dio.post('/delete_saved_folder.php', data: {'id': id});

        if (res.data['success'] == true) {
          Fluttertoast.showToast(msg: "🗑 Dossier supprimé !");
          _loadFolders();
        }
      } catch (e) {
        Fluttertoast.showToast(msg: "Erreur suppression : $e");
      }
    }
  }

  // =========================================================
  // 🧱 UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        title: const Text("Mes enregistrements"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "Créer un dossier",
            onPressed: _createFolder,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : folders.isEmpty
              ? const Center(
                  child: Text(
                    "Aucun dossier enregistré pour le moment 😄",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFolders,
                  color: primary,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: folders.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemBuilder: (context, i) {
                      final f = folders[i];
                      final cover = (f['couverture'] ??
                              'https://zuachat.com/assets/dossiervide.jpg')
                          .toString();
                      final name = (f['nom'] ?? 'Sans nom').toString();
                      final count = f['total_pub'] ?? 0;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SavedFolderPage(
                                folderId: f['id'],
                                folderName: name,
                              ),
                            ),
                          );
                        },
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  cover,
                                  height: double.infinity,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.folder, size: 40),
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              Positioned(
                                bottom: 10,
                                left: 10,
                                right: 10,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      "$count publication(s)",
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert,
                                      color: Colors.white),
                                  onSelected: (value) {
                                    if (value == 'rename') {
                                      _renameFolder(f);
                                    } else if (value == 'delete') {
                                      _deleteFolder(f['id']);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'rename',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, color: Colors.blue),
                                          SizedBox(width: 8),
                                          Text("Renommer"),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text("Supprimer"),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
