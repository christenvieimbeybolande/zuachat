import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUpdatePage extends StatelessWidget {
  final String message;
  final String storeUrl;
  final bool force;

  const AppUpdatePage({
    super.key,
    required this.message,
    required this.storeUrl,
    required this.force,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !force, // ⛔ bloqué si force=true
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.system_update, size: 90, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  "Mise à jour requise",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    launchUrl(
                      Uri.parse(storeUrl),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: const Text("Mettre à jour"),
                ),
                if (!force) ...[
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('ignore_update', true);
                      Navigator.pop(context);
                    },
                    child: const Text("Fermer"),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
