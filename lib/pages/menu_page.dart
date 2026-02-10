import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../gen_l10n/app_localizations.dart';

import '../widgets/bottom_nav.dart';
import '../widgets/zua_loader.dart';
import '../api/client.dart';
import '../api/auth_logout.dart';

import 'profile_page.dart';
import 'feed_page.dart';
import 'friends_page.dart';
import 'notifications_page.dart';
import 'saved_page.dart';
import 'settings_page.dart';
import 'help_page.dart';
import 'helps_page.dart';
import 'dashboard_page.dart';
import 'zuaverifie_page.dart';
import 'login_page.dart';
import 'reels_page.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  bool _loading = true;
  bool _offline = false;

  Map<String, dynamic>? _user;
  Map<String, dynamic>? _badgeRequest;

  int unreadMessages = 0;
  int unreadNotifications = 0;

  static const Color primary = Color.fromARGB(255, 255, 0, 0);

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  // ============================================================
  // AUTH CHECK
  // ============================================================
  Future<void> _checkAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final session = prefs.getString('current_session_id');

    if (token == null || token.isEmpty || session == null || session.isEmpty) {
      _redirectToLogin();
      return;
    }

    _loadMenuData();
  }

  void _redirectToLogin() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  // ============================================================
  // LOAD MENU DATA
  // ============================================================
  Future<void> _loadMenuData() async {
    try {
      final dio = await ApiClient.authed();
      final res = await dio.get('/fetch_profile.php');

      if (!mounted) return;

      if (res.statusCode == 200 && res.data['success'] == true) {
        final data = res.data['data'] ?? {};
        final user = data['user'] ?? {};
        final unread = data['unread'] ?? {};

        setState(() {
          _user = user;
          _badgeRequest = user['badge_request'];
          unreadMessages = unread['messages'] ?? 0;
          unreadNotifications = unread['notifications'] ?? 0;
          _offline = false;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _offline = true;
        _loading = false;
      });
    }
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: ZuaLoader(size: 140, looping: true)),
      );
    }

    final user = _user ?? {};
    final verified = user['badge_verified'] == 1;
    final badgeStatus = _badgeRequest?['status'];

    final photo =
        (user['photo'] ?? 'https://zuachat.com/assets/default-avatar.png')
            .toString();

    final fullName = "${user['prenom'] ?? ''} ${user['nom'] ?? ''}".trim();

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const FeedPage()),
          (_) => false,
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: primary,
          title: Text(
            t.menu,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: RefreshIndicator(
          onRefresh: _loadMenuData,
          color: primary,
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              if (_offline)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  color: Colors.orange.shade200,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.wifi_off, size: 14),
                      SizedBox(width: 6),
                      Text(
                        "Hors connexion – certaines sections nécessitent Internet",
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              _profileCard(theme, photo, fullName, user['username']),
              const SizedBox(height: 16),
              _menuItem(Icons.home, t.home, () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const FeedPage()),
                );
              }),
              _menuItem(Icons.group, t.friends, () {
                _requireOnline(() {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const FriendsPage()),
                  );
                });
              }),
              _menuItem(Icons.video_collection, t.reels, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReelsPage(initialReelId: 0),
                  ),
                );
              }),
              _menuItem(Icons.notifications, t.notifications, () {
                _requireOnline(() {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationsPage()),
                  );
                });
              }),
              _menuItem(Icons.bookmark, t.saved, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SavedPage()),
                );
              }),
              _menuItem(Icons.bar_chart, t.dashboard, () {
                _requireOnline(() {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DashboardPage()),
                  );
                });
              }),
              _menuItem(
                Icons.verified,
                t.verify,
                () {
                  if (verified) {
                    _snack(t.already_verified);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ZuaVerifiePage()),
                    );
                  }
                },
                color: verified
                    ? Colors.green
                    : badgeStatus == 'pending'
                        ? Colors.orange
                        : badgeStatus == 'refused'
                            ? Colors.red
                            : Colors.blue,
              ),
              _menuItem(Icons.settings, t.settings, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              }),
              _menuItem(Icons.help_outline, t.help, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpPage()),
                );
              }),
              const SizedBox(height: 16),
              _menuItem(Icons.support_agent, t.support_center, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpsPage()),
                );
              }),
              _menuItem(Icons.logout, t.logout, () async {
                await apiLogout();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (_) => false,
                );
              }, color: Colors.red),
            ],
          ),
        ),
        bottomNavigationBar: BottomNav(
          currentIndex: 4,
          unreadMessages: unreadMessages,
          unreadNotifications: unreadNotifications,
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================
  void _requireOnline(VoidCallback action) {
    if (_offline) {
      _snack("Connexion Internet requise pour cette section");
      return;
    }
    action();
  }

  Widget _profileCard(
    ThemeData theme,
    String photo,
    String name,
    String? username,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundImage: CachedNetworkImageProvider(photo),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : '—',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(username ?? '—', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _menuItem(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: primary),
        title: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: color),
        ),
        onTap: onTap,
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
