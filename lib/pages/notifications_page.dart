import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../api/notifications.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/zua_loader.dart';
import '../widgets/verified_badge.dart';
import '../utils/notification_counter.dart';
import '../gen_l10n/app_localizations.dart';

import 'feed_page.dart';
import 'single_publication_page.dart';
import 'admin_notification_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  bool _error = false;

  List<dynamic> _notifications = [];

  int unreadMessages = 0;
  int unreadNotifications = 0;

  static const Color primary = Color(0xFFFF0000);
  static const Color bg = Color(0xFFF0F2F5);
  static const Color unreadBg = Color(0xFFFFE8E8);

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  // =========================================================
  // 📡 LOAD
  // =========================================================
  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    final res = await fetchNotifications();

    if (res['success'] == true && res['data'] is Map) {
      final data = Map<String, dynamic>.from(res['data']);

      setState(() {
        _notifications = data['notifications'] ?? [];
        unreadMessages = data['unread_messages'] ?? 0;
        unreadNotifications = data['unread_notifications'] ?? 0;
      });

      NotificationCounter.update(
        notifications: unreadNotifications,
        messages: unreadMessages,
      );
    } else {
      setState(() => _error = true);
    }

    setState(() => _loading = false);
  }

  // =========================================================
  // 👉 OPEN NOTIF
  // =========================================================
  void _openNotification(dynamic n) {
    final String type = (n['type'] ?? '').toString();

    // 🔔 ADMIN CUSTOM
    if (type == 'admin_custom') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminNotificationPage(notification: n),
        ),
      );
      return;
    }

    final int? publicationId = n['publication_id'] == null
        ? null
        : int.tryParse(n['publication_id'].toString());

    const openPublicationTypes = [
      'like',
      'comment',
      'reply',
      'share',
      'share_received',
      'save',
    ];

    if (publicationId != null && openPublicationTypes.contains(type)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SinglePublicationPage(publicationId: publicationId),
        ),
      );
    }
  }

  // =========================================================
  // 🧱 UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FeedPage()),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF18191A) : bg,
        appBar: AppBar(
          backgroundColor: primary,
          centerTitle: true,
          title: Text(
            t.notifications,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const FeedPage()),
              );
            },
          ),
        ),
        bottomNavigationBar: BottomNav(
          currentIndex: 3,
          unreadNotifications: NotificationCounter.unreadNotifications,
          unreadMessages: NotificationCounter.unreadMessages,
        ),
        body: _loading
            ? const Center(child: ZuaLoader(size: 120, looping: true))
            : _error
                ? _buildError(t)
                : RefreshIndicator(
                    color: primary,
                    onRefresh: _loadNotifications,
                    child: _notifications.isEmpty
                        ? Center(
                            child: Text(
                              t.no_notifications,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(10),
                            itemCount: _notifications.length,
                            itemBuilder: (context, index) {
                              final n = _notifications[index];
                              final sender =
                                  (n['sender'] ?? {}) as Map<String, dynamic>;

                              final bool seen = n['seen'] == 1;
                              final bool verified =
                                  sender['badge_verified'] == 1;

                              final avatar = sender['photo'] ??
                                  'https://zuachat.com/assets/default-avatar.png';

                              return InkWell(
                                onTap: () => _openNotification(n),
                                child: Card(
                                  color: seen
                                      ? (isDark
                                          ? const Color(0xFF242526)
                                          : Colors.white)
                                      : unreadBg,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundImage:
                                              CachedNetworkImageProvider(
                                                  avatar),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      sender['fullname'] ??
                                                          'ZuaChat',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  if (verified)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 4),
                                                      child: VerifiedBadge.mini(
                                                        isVerified: true,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _notificationText(t, n['type']),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                n['time_ago'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
      ),
    );
  }

  // =========================================================
  // ❌ ERROR
  // =========================================================
  Widget _buildError(AppLocalizations t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          Text(t.error_loading_notifications),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadNotifications,
            style: ElevatedButton.styleFrom(backgroundColor: primary),
            child: Text(t.retry),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // 📝 TEXT BY TYPE
  // =========================================================
  String _notificationText(AppLocalizations t, String? type) {
    switch (type) {
      case 'like':
        return t.notif_like;
      case 'comment':
        return t.notif_comment;
      case 'reply':
        return t.notif_reply;
      case 'share':
        return t.notif_share;
      case 'share_received':
        return t.notif_share_received;
      case 'save':
        return t.notif_save;
      case 'follow':
        return t.notif_follow;
      case 'badge_accept':
        return t.notif_badge_accept;
      case 'badge_refuse':
        return t.notif_badge_refuse;
      case 'badge_removed':
        return t.notif_badge_removed;
      case 'admin_custom':
        return t.notif_admin;
      default:
        return t.notif_default;
    }
  }
}
