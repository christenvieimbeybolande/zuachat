import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:dio/dio.dart';

import '../api/client.dart';
import '../widgets/publication_card.dart';

class SavedFolderPage extends StatefulWidget {
  final int folderId;
  final String folderName;

  const SavedFolderPage({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  @override
  State<SavedFolderPage> createState() => _SavedFolderPageState();
}

class _SavedFolderPageState extends State<SavedFolderPage> {
  static const Color primary = Color(0xFFFF0000);

  bool loading = true;
  List<Map<String, dynamic>> publications = [];

  @override
  void initState() {
    super.initState();
    _loadPublications();
  }

  // =========================================================
  // 📥 Charger publications du dossier
  // =========================================================
  Future<void> _loadPublications() async {
    setState(() => loading = true);

    try {
      final dio = await ApiClient.authed();
      final res = await dio.get(
        '/saved_folder_content.php',
        queryParameters: {
          'dossier_id': widget.folderId,
        },
      );

      if (res.data['success'] == true && res.data['data'] is List) {
        setState(() {
          publications = List<Map<String, dynamic>>.from(res.data['data']);
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
        title: Text(widget.folderName),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : publications.isEmpty
              ? const Center(
                  child: Text(
                    "Aucune publication enregistrée ici 😄",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  color: primary,
                  onRefresh: _loadPublications,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 10),
                    itemCount: publications.length,
                    itemBuilder: (context, i) {
                      final pub = publications[i];

                      return PublicationCard(
                        publication: pub,
                        authedDio: ApiClient.authed,
                        onRefresh: _loadPublications,
                        showMenu: true,
                        isSavedFolder: true, // 🔥 IMPORTANT
                      );
                    },
                  ),
                ),
    );
  }
}
