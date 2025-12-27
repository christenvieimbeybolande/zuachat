import 'dart:convert';
import 'package:flutter/material.dart';
import '../api/fetch_masked_publications.dart';
import '../api/unmask_publication.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/zua_loader.dart';
import '../api/client.dart';

class ReactiverPublicationsPage extends StatefulWidget {
  const ReactiverPublicationsPage({super.key});

  @override
  State<ReactiverPublicationsPage> createState() =>
      _ReactiverPublicationsPageState();
}

class _ReactiverPublicationsPageState extends State<ReactiverPublicationsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _publications = [];

  @override
  void initState() {
    super.initState();
    _loadMasquees();
  }

  Future<void> _loadMasquees() async {
    final res = await fetchMaskedPublications();

    if (res['success'] == true && res['data'] is List) {
      setState(() {
        _publications = List<Map<String, dynamic>>.from(res['data']);
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Erreur de chargement'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _reactiver(int id) async {
    final res = await unmaskPublication(id);

    if (res['success'] == true) {
      setState(() {
        _publications.removeWhere((p) => p['id'] == id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Publication réactivée !")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ ${res['message'] ?? 'Erreur de réactivation'}"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1877F2);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: primary,
        title: const Text("Réactiver publications"),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 4),
      body: _loading
          ? const Center(child: ZuaLoader(size: 120))
          : _publications.isEmpty
              ? const Center(
                  child: Text(
                    "Aucune publication masquée 👌",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMasquees,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // 🔵 2 par ligne
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.78, // 🔥 mini-carte style Instagram
                    ),
                    itemCount: _publications.length,
                    itemBuilder: (context, index) {
                      final pub = _publications[index];

                      // 🔵 Convertir fichiers si string
                      List<String> images = [];
                      try {
                        if (pub['fichiers'] is String &&
                            pub['fichiers'].toString().trim().isNotEmpty) {
                          images =
                              List<String>.from(json.decode(pub['fichiers']));
                        } else if (pub['fichiers'] is List) {
                          images = pub['fichiers']
                              .map<String>((e) => e.toString())
                              .toList();
                        }
                      } catch (_) {
                        images = [];
                      }

                      // 🔥 Mini-carte : juste l'image principale
                      final String? mainImage =
                          images.isNotEmpty ? images.first : null;

                      return Stack(
                        children: [
                          // 🔵 Mini-carte style Instagram
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              color: Colors.white,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: mainImage != null
                                        ? Image.network(
                                            mainImage,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            color: Colors.grey[300],
                                            child: const Icon(
                                              Icons.image_not_supported,
                                              size: 40,
                                              color: Colors.grey,
                                            ),
                                          ),
                                  ),

                                  // Petite barre en bas
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(6),
                                    color: Colors.white,
                                    child: Text(
                                      pub['texte']?.toString() ?? "",
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 🔵 Bouton réactiver
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.refresh,
                                    size: 20, color: Colors.white),
                                onPressed: () => _reactiver(pub['id']),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
    );
  }
}
