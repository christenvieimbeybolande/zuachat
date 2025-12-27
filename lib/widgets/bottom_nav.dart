import 'package:flutter/material.dart';

import '../gen_l10n/app_localizations.dart';

import '../pages/feed_page.dart';
import '../pages/friends_page.dart';
import '../pages/profile_page.dart';
import '../pages/menu_page.dart';
import '../pages/notifications_page.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final int unreadNotifications;
  final int unreadMessages;

  const BottomNav({
    super.key,
    required this.currentIndex,
    this.unreadNotifications = 0,
    this.unreadMessages = 0,
  });

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;

    Widget page;
    switch (index) {
      case 0:
        page = const FeedPage();
        break;
      case 1:
        page = const FriendsPage();
        break;
      case 2:
        page = const ProfilePage();
        break;
      case 3:
        page = const NotificationsPage();
        break;
      case 4:
        page = const MenuPage();
        break;
      default:
        page = const FeedPage();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (i) => _onTap(context, i),
      selectedItemColor: const Color(0xFFFF0000),
      unselectedItemColor: Colors.grey[600],
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home_outlined),
          activeIcon: const Icon(Icons.home),
          label: t.nav_home,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.group_outlined),
          activeIcon: const Icon(Icons.group),
          label: t.nav_friends,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.person_outline),
          activeIcon: const Icon(Icons.person),
          label: t.nav_profile,
        ),

        /// 🔔 NOTIFICATIONS AVEC BADGE
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined),
              if (unreadNotifications > 0)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadNotifications > 9
                          ? '9+'
                          : unreadNotifications.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          activeIcon: const Icon(Icons.notifications),
          label: t.nav_notifications,
        ),

        BottomNavigationBarItem(
          icon: const Icon(Icons.menu),
          activeIcon: const Icon(Icons.menu_open),
          label: t.nav_menu,
        ),
      ],
    );
  }
}
