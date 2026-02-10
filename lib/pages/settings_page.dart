import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/bottom_nav.dart';
import '../widgets/zua_loader.dart';

import '../api/client.dart';
import '../theme/theme_controller.dart';

import '../gen_l10n/app_localizations.dart';
import 'manage_services_page.dart';

import 'edit_profile_page.dart';
import 'notifications_page.dart';
import 'privacy_policy_page.dart';
import 'connected_devices_page.dart';
import 'login_page.dart';
import 'change_password_page.dart';
import 'store_account_page.dart';
import 'language_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loading = false;

  static const Color primary = Color.fromARGB(255, 255, 0, 0);
  static const Color bg = Color(0xFFF0F2F5);

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final session = prefs.getString('current_session_id');

    if (token == null || token.isEmpty || session == null || session.isEmpty) {
      _redirectToLogin();
    }
  }

  void _redirectToLogin() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = context.watch<ThemeController>();

    if (_loading) {
      return const Scaffold(
        body: Center(child: ZuaLoader(size: 100, looping: true)),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF18191A) : bg,
      appBar: AppBar(
        backgroundColor: primary,
        title: Text(
          t.settings,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 4),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _sectionTitle(t.profile_info),
          _tile(
            icon: Icons.edit,
            label: t.edit_profile,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfilePage()),
            ),
          ),
          const SizedBox(height: 12),
          _sectionTitle(t.security),
          _tile(
            icon: Icons.lock_open_outlined,
            label: t.change_password,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
            ),
          ),
          _tile(
            icon: Icons.devices_other,
            label: t.connected_devices,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConnectedDevicesPage()),
            ),
          ),
          const SizedBox(height: 12),
          _sectionTitle(t.appearance),
          _tile(
            icon: Icons.dark_mode_outlined,
            label: t.dark_mode,
            trailing: Switch(
              value: theme.isDark,
              activeColor: primary,
              onChanged: (v) async {
                await theme.toggleTheme(v);
                try {
                  final dio = await ApiClient.authed();
                  await dio.post(
                    '/update_user_theme.php',
                    data: {'theme': v ? 'dark' : 'light'},
                  );
                } catch (_) {}
              },
            ),
            onTap: null,
          ),
          const SizedBox(height: 12),
          _sectionTitle(t.language),
          _tile(
            icon: Icons.language_outlined,
            label: t.choose_language,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LanguageSettingsPage(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _sectionTitle(t.others),
          _tile(
            icon: Icons.privacy_tip_outlined,
            label: t.privacy_policy,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PrivacyPolicyPage(),
              ),
            ),
          ),
          _tile(
            icon: Icons.notifications_active_outlined,
            label: t.notifications,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationsPage(),
              ),
            ),
          ),
          _tile(
            icon: Icons.delete_forever_outlined,
            label: t.delete_account,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const StoreAccountPage(),
              ),
            ),
          ),
          const SizedBox(height: 30),
          _sectionTitle(t.account),
          _tile(
            icon: Icons.apps_outlined,
            label: 'Gérer mon accès ZuaChat',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ManageServicesPage(),
                ),
              );
            },
          ),
          _tile(
            icon: Icons.logout,
            label: t.logout,
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              await ApiClient.reset();

              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      );

  Widget _tile({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: primary),
      title: Text(label),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      tileColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }
}
