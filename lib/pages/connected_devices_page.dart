import 'package:flutter/material.dart';
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

  // 🔴 Couleur officielle ZuaChat
  static const Color primary = Color(0xFFFF0000);

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
  // Helpers affichage
  // ============================================================

  String _deviceName(String ua) {
    final l = ua.toLowerCase();

    if (l.contains('dart')) return 'Dernière connexion';
    if (l.contains('android')) return 'Appareil Android';
    if (l.contains('iphone')) return 'iPhone';
    if (l.contains('ipad')) return 'iPad';
    if (l.contains('ios')) return 'Appareil iOS';
    if (l.contains('windows')) return 'Ordinateur Windows';
    if (l.contains('mac')) return 'Mac';
    if (l.contains('linux')) return 'Ordinateur Linux';

    return 'Appareil inconnu';
  }

  Icon _platformIcon(String ua) {
    final l = ua.toLowerCase();

    if (l.contains('dart')) {
      return const Icon(Icons.access_time, color: Colors.grey);
    }
    if (l.contains('android')) {
      return const Icon(Icons.android, color: Colors.green);
    }
    if (l.contains('iphone') || l.contains('ipad') || l.contains('ios')) {
      return const Icon(Icons.phone_iphone, color: Colors.blue);
    }
    if (l.contains('windows')) {
      return const Icon(Icons.laptop_windows, color: Colors.blueGrey);
    }
    if (l.contains('mac')) {
      return const Icon(Icons.laptop_mac, color: Colors.black);
    }
    if (l.contains('linux')) {
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
        body: Center(child: ZuaLoader(size: 120, looping: true)),
      );
    }

    if (_error) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: primary,
          title: const Text(
            "Appareils connectés",
            style: TextStyle(color: Colors.white),
          ),
        ),
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
        elevation: 0,
        title: const Text(
          "Appareils connectés",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (_currentSessionId == null) return;

              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Déconnecter les autres sessions"),
                  content: const Text(
                    "Seule la session actuelle sera conservée.\n\nContinuer ?",
                  ),
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
                        "Toutes les autres sessions ont été déconnectées."),
                  ),
                );
                _loadSessions();
              }
            },
            child: const Text(
              "Déconnecter autres",
              style: TextStyle(color: Colors.white),
            ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _platformIcon(s["user_agent"] ?? ""),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _deviceName(s["user_agent"] ?? ""),
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
                    "Dernière connexion : ${s["last_activity"]}",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _status(isCurrent, revoked),
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
      return const Text(
        "Session actuelle",
        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
      );
    }
    if (revoked) {
      return const Text(
        "Révoquée",
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      );
    }
    return const Text(
      "Active",
      style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
    );
  }
}
