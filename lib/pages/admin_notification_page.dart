import 'package:flutter/material.dart';
import '../gen_l10n/app_localizations.dart';

class AdminNotificationPage extends StatelessWidget {
  final dynamic notification;

  const AdminNotificationPage({
    super.key,
    required this.notification,
  });

  static const Color primary = Color(0xFFFF0000);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    final Map<String, dynamic> admin =
        (notification['admin'] ?? {}) as Map<String, dynamic>;

    final String title =
        admin['title']?.toString() ?? t.notif_admin;

    final String message =
        admin['message']?.toString() ?? '';

    final String timeAgo =
        notification['time_ago']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        title: Text(
          t.notification,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔔 BADGE
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "ZuaChat",
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 📝 TITLE
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // 📄 MESSAGE
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 20),

            // ⏱️ TIME
            Text(
              timeAgo,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
