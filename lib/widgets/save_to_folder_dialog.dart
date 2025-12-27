import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:dio/dio.dart';
import '../api/client.dart';
import '../api/save_publication.dart';

class SaveToFolderDialog extends StatefulWidget {
  final int publicationId;
  const SaveToFolderDialog({super.key, required this.publicationId});

  @override
  State<SaveToFolderDialog> createState() => _SaveToFolderDialogState();
}

class _SaveToFolderDialogState extends State<SaveToFolderDialog> {
  bool loading = true;
  List<Map<String, dynamic>> folders = [];

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

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
            msg: res.data['message'] ?? 'Erreur de chargement');
        setState(() => loading = false);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Erreur réseau : $e");
      setState(() => loading = false);
    }
  }

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
              child: const Text("Annuler")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Créer")),
        ],
      ),
    );

    if (created == true && controller.text.trim().isNotEmpty) {
      try {
        final dio = await ApiClient.authed();
        final res = await dio.post('/create_saved_folder.php', data: {
          'nom': controller.text.trim(),
        });
        if (res.data['success'] == true) {
          Fluttertoast.showToast(msg: "Dossier créé !");
          _loadFolders();
        } else {
          Fluttertoast.showToast(
              msg: res.data['message'] ?? "Erreur création dossier");
        }
      } catch (e) {
        Fluttertoast.showToast(msg: "Erreur : $e");
      }
    }
  }

  Future<void> _saveToFolder(int folderId, String folderName) async {
    Fluttertoast.showToast(msg: "Enregistrement dans '$folderName'...");

    final res = await savePublication(
      publicationId: widget.publicationId,
      folderId: folderId,
    );

    if (res['success'] == true) {
      Fluttertoast.showToast(msg: "Enregistré dans '$folderName'");
      Navigator.pop(context, true);
    } else {
      Fluttertoast.showToast(
        msg: "❌ ${res['message'] ?? 'Erreur'}",
        backgroundColor: Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 420,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        "Enregistrer dans...",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline,
                            color: Colors.blue),
                        onPressed: _createFolder,
                      ),
                    ],
                  ),
                  const Divider(),
                  if (folders.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.folder_open,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            const Text("Aucun dossier trouvé"),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              icon:
                                  const Icon(Icons.create_new_folder_outlined),
                              label: const Text("Créer un dossier"),
                              onPressed: _createFolder,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: folders.length,
                        itemBuilder: (context, i) {
                          final f = folders[i];
                          return ListTile(
                            leading:
                                const Icon(Icons.folder, color: Colors.blue),
                            title: Text(f['nom'] ?? 'Sans nom'),
                            subtitle: Text("${f['total_pub']} publication(s)"),
                            onTap: () => _saveToFolder(f['id'], f['nom']),
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
