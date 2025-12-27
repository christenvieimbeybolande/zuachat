import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../api/client.dart';
import '../widgets/zua_loader.dart';

class ConnectedDevicesPage extends StatefulWidget {
  const ConnectedDevicesPage({super.key});

  @override
  State<ConnectedDevicesPage> createState() => _ConnectedDevicesPageState();
}

class _ConnectedDevicesPageState extends State<ConnectedDevicesPage> {
  bool _loading = true;
  bool _error = false;

  List<dynamic> _sessions = [];
  String? _currentSessionId;

  static const primary = Color(0xFF1877F2);

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  // ============================================================
  // API
  // ============================================================

  Future<Map<String, dynamic>> fetchUserSessions() async {
    final dio = await ApiClient.authed();
    final res = await dio.get('/get_sessions.php');

    if (res.statusCode == 200 && res.data['success'] == true) {
      return res.data;
    }
    return {"success": false};
  }

  Future<bool> revokeSession(String id) async {
    final dio = await ApiClient.authed();
    final res = await dio.post('/revoke_session.php', data: {
      'session_id': id,
    });
    return res.data['success'] == true;
  }

  Future<Map<String, dynamic>> deleteSession(String id) async {
    final dio = await ApiClient.authed();
    final res = await dio.post('/delete_session.php', data: {
      'session_id': id,
    });
    return Map<String, dynamic>.from(res.data);
  }

  Future<bool> revokeOthersSessions(String currentSession) async {
    final dio = await ApiClient.authed();
    final res = await dio.post('/revoke_others_sessions.php', data: {
      'current_session': currentSession,
    });
    return res.data['success'] == true;
  }

  // ============================================================
  // Chargement sessions
  // ============================================================

  Future<void> _loadSessions() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    final res = await fetchUserSessions();

    if (!mounted) return;

    if (res['success'] == true) {
      final list = res['sessions'];

      setState(() {
        _sessions = list;
        for (var s in list) {
          if (s['is_current'] == true || s['is_current'] == 1) {
            _currentSessionId = s['session_id'];
          }
        }
      });
    } else {
      _error = true;
    }

    setState(() => _loading = false);
  }

  // ============================================================
  // Confirmation + Loader
  // ============================================================

  Future<void> _confirmAction({
    required BuildContext context,
    required Map<String, dynamic> session,
    required String actionLabel,
    required Future<void> Function() onConfirm,
  }) async {
    final isCurrent = session["is_current"] == true;

    final icon =
        actionLabel == "Supprimer" ? Icons.delete_forever : Icons.logout;

    final color = actionLabel == "Supprimer" ? Colors.red : Colors.orange;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text("$actionLabel la session", style: TextStyle(color: color)),
          ],
        ),
        content: Text(
          isCurrent
              ? "Vous êtes sur le point d'agir sur la session ACTUELLE.\n\nVous serez automatiquement déconnecté si vous continuez."
              : "Êtes-vous sûr de vouloir $actionLabel cette session ?",
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    await onConfirm();

    Navigator.of(context).pop(); // Fermer loader
  }

  // ============================================================
  // Icône plateforme
  // ============================================================

  Widget _platformIcon(String ua) {
    final userAgent = ua.toLowerCase();

    if (userAgent.contains("android")) {
      return const Icon(Icons.android, color: Colors.green);
    }
    if (userAgent.contains("iphone") ||
        userAgent.contains("ios") ||
        userAgent.contains("ipad")) {
      return const Icon(Icons.phone_iphone, color: Colors.blue);
    }
    if (userAgent.contains("windows")) {
      return const Icon(Icons.laptop_windows, color: Colors.blueGrey);
    }
    if (userAgent.contains("mac") || userAgent.contains("os x")) {
      return const Icon(Icons.laptop_mac, color: Colors.black);
    }
    if (userAgent.contains("linux")) {
      return const Icon(Icons.laptop, color: Colors.orange);
    }

    return const Icon(Icons.devices_other);
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Scaffold(
        body: Center(child: ZuaLoader(size: 130, looping: true)),
      );
    }

    if (_error) {
      return Scaffold(
        appBar: AppBar(
            backgroundColor: primary, title: const Text("Appareils connectés")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 10),
              const Text("Impossible de charger les sessions"),
              ElevatedButton(
                onPressed: _loadSessions,
                child: const Text("Réessayer"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        title: const Text("Appareils connectés"),
        actions: [
          TextButton(
            onPressed: () async {
              if (_currentSessionId == null) return;

              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Déconnecter les autres sessions"),
                  content: const Text(
                      "Cette action conservera uniquement votre session actuelle.\n\nContinuer ?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Annuler"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Déconnecter"),
                    ),
                  ],
                ),
              );

              if (confirm != true) return;

              final ok = await revokeOthersSessions(_currentSessionId!);

              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          "Toutes les autres sessions ont été déconnectées.")),
                );
                _loadSessions();
              }
            },
            child: const Text("Déconnecter autres",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _sessions.length,
        itemBuilder: (context, i) {
          final s = _sessions[i];
          final bool isCurrent = s["is_current"] == true;
          final bool revoked = s["revoked"] == 1;

          return Card(
            color: isCurrent
                ? Colors.green.shade50
                : revoked
                    ? Colors.red.shade50
                    : (isDark ? const Color(0xFF242526) : Colors.white),
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _platformIcon(s["user_agent"]),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s["user_agent"],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Créée : ${s["created_at"]}\nDernière activité : ${s["last_activity"]}",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[300] : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _status(isCurrent, revoked),
                  const SizedBox(height: 12),
                  if (!isCurrent)
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _confirmAction(
                            context: context,
                            session: s,
                            actionLabel: "Déconnecter",
                            onConfirm: () async {
                              final ok = await revokeSession(s["session_id"]);
                              if (ok) _loadSessions();
                            },
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text("Déconnecter"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () => _confirmAction(
                            context: context,
                            session: s,
                            actionLabel: "Supprimer",
                            onConfirm: () async {
                              final result =
                                  await deleteSession(s["session_id"]);

                              if (result["success"] == true) {
                                // Si c'était la session actuelle
                                if (result["logout_required"] == true) {
                                  await ApiClient.logoutLocal();

                                  if (!mounted) return;

                                  // 🔥 Fermer le loader AVANT la navigation
                                  Navigator.of(context).pop();

                                  // 🔥 Navigation propre après fermeture du dialog
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    Navigator.of(context)
                                        .pushNamedAndRemoveUntil(
                                      '/login',
                                      (route) => false,
                                    );
                                  });

                                  return;
                                }

                                // Sinon continuer normalement
                                _loadSessions();
                              }
                            },
                          ),
                          icon: const Icon(Icons.delete_forever),
                          label: const Text("Supprimer"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _status(bool isCurrent, bool revoked) {
    if (isCurrent) {
      return const Text("Session actuelle",
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
    }
    if (revoked) {
      return const Text("Révoquée",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold));
    }
    return const Text("Active",
        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold));
  }
}
