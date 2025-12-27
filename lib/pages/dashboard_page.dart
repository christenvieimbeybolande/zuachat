import 'package:flutter/material.dart';
import '../api/dashboard_api.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const Color primary = Color(0xFFFF0000);

  bool loading = true;
  bool error = false;
  Map<String, dynamic>? stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = false;
    });

    try {
      final data = await fetchDashboard();
      if (!mounted) return;

      setState(() {
        stats = data;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = true;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text(
          "Tableau de bord",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: primary),
            )
          : error
              ? _buildError(theme)
              : RefreshIndicator(
                  color: primary,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _statCard(
                        theme,
                        "Publications",
                        stats!['nb_publications'],
                      ),
                      _statCard(
                        theme,
                        "Messages reçus",
                        stats!['nb_messages'],
                      ),
                      _statCard(
                        theme,
                        "Amis actuels",
                        stats!['nb_amis'],
                      ),
                      _statCard(
                        theme,
                        "Nouveaux amis (7 jours)",
                        stats!['nb_amis_7j'],
                      ),
                      _statCard(
                        theme,
                        "Vues des statuts (24h)",
                        stats!['nb_vues_statuts'],
                      ),
                    ],
                  ),
                ),
    );
  }

  // ===================== CARTE STAT =====================

  Widget _statCard(ThemeData theme, String title, dynamic value) {
    return Card(
      color: theme.cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              "$value",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== ERREUR =====================

  Widget _buildError(ThemeData theme) {
    return Center(
      child: ElevatedButton(
        onPressed: _load,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
        child: const Text("Réessayer"),
      ),
    );
  }
}
