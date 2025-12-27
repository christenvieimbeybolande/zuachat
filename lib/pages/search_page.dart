import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../api/fetch_search.dart';
import '../api/client.dart';
import '../widgets/publication_card.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/zua_loader.dart';
import '../widgets/verified_badge.dart';
import 'user_profile.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _ctrl = TextEditingController();

  bool _loading = false;
  bool _searching = false;

  List profils = [];
  List publications = [];

  static const primary = Color(0xFFFF0000);

  // ======================================================
  // 🔍 Recherche instantanée (debounce simple)
  // ======================================================
  void _instantSearch(String text) {
    if (text.trim().isEmpty) {
      setState(() {
        profils = [];
        publications = [];
        _searching = false;
      });
      return;
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_ctrl.text == text) _doSearch();
    });
  }

  // ======================================================
  // 🌐 Appel API
  // ======================================================
  Future<void> _doSearch() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _loading = true;
      _searching = true;
    });

    try {
      final res = await fetchSearch(q);

      if (!mounted) return;

      if (res["success"] == true) {
        final data = res["data"] ?? {};
        profils = data["profils"] ?? [];
        publications = data["publications"] ?? [];
      } else {
        profils = [];
        publications = [];
      }
    } catch (_) {
      profils = [];
      publications = [];
    }

    if (mounted) setState(() => _loading = false);
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: _instantSearch,
          onSubmitted: (_) => _doSearch(),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Rechercher...",
            hintStyle: const TextStyle(color: Colors.white70),
            border: InputBorder.none,
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() {
                        profils = [];
                        publications = [];
                        _searching = false;
                      });
                    },
                  )
                : null,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _doSearch,
          ),
        ],
      ),

      // ---------------------------
      // CONTENU
      // ---------------------------
      body: _loading
          ? const Center(child: ZuaLoader(size: 120, looping: true))
          : !_searching
              ? Center(
                  child: Text(
                    "Tapez quelque chose pour rechercher 🔍",
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.grey),
                  ),
                )
              : _buildResults(),

      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }

  // ======================================================
  // Résultats
  // ======================================================
  Widget _buildResults() {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // ------------------------
        // 👤 PROFILS
        // ------------------------
        if (profils.isNotEmpty) ...[
          Text(
            "Profils",
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...profils.map(_buildProfileCard),
          const SizedBox(height: 25),
        ],

        // ------------------------
        // 📰 PUBLICATIONS
        // ------------------------
        if (publications.isNotEmpty) ...[
          Text(
            "Publications",
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
        ],

        ...publications.map(
          (pub) => PublicationCard(
            publication: pub,
            authedDio: () async => ApiClient.authed(),
            onRefresh: () {},
            isFromProfile: false,
            onLikeNetworkStart: () {},
            onLikeNetworkDone: (_) {},
          ),
        ),

        // Aucun résultat
        if (profils.isEmpty && publications.isEmpty)
          Column(
            children: [
              const SizedBox(height: 40),
              Icon(Icons.search_off, size: 60, color: theme.hintColor),
              const SizedBox(height: 10),
              Text(
                "Aucun résultat trouvé",
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
            ],
          ),
      ],
    );
  }

  // ======================================================
  // Carte profil
  // ======================================================
  Widget _buildProfileCard(dynamic u) {
    final theme = Theme.of(context);

    String img = u["photo"] ?? "";
    if (img.isNotEmpty && !img.startsWith("http")) {
      img = "https://zuachat.com/$img";
    }

    final nom =
        "${u['prenom'] ?? ''} ${u['postnom'] ?? ''} ${u['nom'] ?? ''}".trim();
    final verified = u["badge_verified"] == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            blurRadius: 3,
            spreadRadius: 1,
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: img.isNotEmpty
              ? CachedNetworkImageProvider(img)
              : const AssetImage("assets/default-avatar.png") as ImageProvider,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                nom.isEmpty ? "Utilisateur" : nom,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (verified) const VerifiedBadge(isVerified: true, size: 18),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  UserProfilePage(userId: int.parse(u["id"].toString())),
            ),
          );
        },
      ),
    );
  }
}
