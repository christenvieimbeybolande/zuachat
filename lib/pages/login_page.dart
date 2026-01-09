import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import '../api/client.dart'; // ton ApiClient

import '../api/auth_login.dart';
import '../theme/theme_controller.dart';
import '../gen_l10n/app_localizations.dart';
import '../main.dart'; // LocaleController

import 'feed_page.dart';
import 'signup_user_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _showPassword = false;
  bool _loading = false;
  String? _message;
  bool _successMsg = false;

  static const primaryColor = Color.fromARGB(255, 255, 0, 0);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ==========================
  // 🔐 LOGIN
  // ==========================
  Future<void> _doLogin() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      await apiLogin(_emailCtrl.text.trim(), _passCtrl.text);




      setState(() {
        _successMsg = true;
        _message = AppLocalizations.of(context)!.login_success;
      });

      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FeedPage()),
      );
    } catch (e) {
      setState(() {
        _successMsg = false;
        _message = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  // ==========================
  // 🖥️ UI
  // ==========================
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            // ==========================
            // 🌍 LANGUE (GAUCHE) | 🎨 THEME (DROITE)
            // ==========================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 🌍 LANGUE
                IconButton(
                  icon: const Icon(Icons.language),
                  tooltip: t.change_language,
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (_) => _LanguageQuickPicker(),
                    );
                  },
                ),

                // 🎨 THEME
                PopupMenuButton<String>(
                  icon: const Icon(Icons.dark_mode),
                  onSelected: (mode) {
                    final themeCtrl = context.read<ThemeController>();
                    if (mode == 'dark') {
                      themeCtrl.toggleTheme(true);
                    } else if (mode == 'light') {
                      themeCtrl.toggleTheme(false);
                    } else {
                      final brightness = WidgetsBinding
                          .instance.platformDispatcher.platformBrightness;
                      themeCtrl.toggleTheme(brightness == Brightness.dark);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'light', child: Text(t.light_mode)),
                    PopupMenuItem(value: 'dark', child: Text(t.dark_mode)),
                    PopupMenuItem(value: 'system', child: Text(t.system_mode)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 30),

            // ==========================
            // 🟥 LOGO
            // ==========================
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/logo2.png', height: 50),
                const SizedBox(width: 10),
                const Text(
                  'ZuaChat',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // ==========================
            // 🔐 FORM
            // ==========================
            Container(
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    t.login,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_message != null)
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _successMsg ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailCtrl,
                    decoration: InputDecoration(
                      labelText: t.email,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      labelText: t.password,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _doLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              t.login,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordPage(),
                      ),
                    ),
                    child: Text(t.forgot_password),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignupUserPage()),
                    ),
                    child: Text(t.no_account),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =========================================================
/// 🌍 LANGUE RAPIDE (LOGIN)
/// =========================================================
class _LanguageQuickPicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final localeCtrl = context.read<LocaleController>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: const Text('Français'),
          onTap: () {
            localeCtrl.setLocale(const Locale('fr'));
            Navigator.pop(context);
          },
        ),
        ListTile(
          title: const Text('English'),
          onTap: () {
            localeCtrl.setLocale(const Locale('en'));
            Navigator.pop(context);
          },
        ),
        ListTile(
          title: const Text('Español'),
          onTap: () {
            localeCtrl.setLocale(const Locale('es'));
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
