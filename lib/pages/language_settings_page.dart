import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../gen_l10n/app_localizations.dart';
import '../main.dart'; // 🔥 LocaleController

class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key});

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  String _currentLang = 'fr';

  @override
  void initState() {
    super.initState();
    _loadLang();
  }

  Future<void> _loadLang() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _currentLang = prefs.getString('app_lang') ?? 'fr';
    });
  }

  Future<void> _changeLang(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lang', code);

    if (!mounted) return;

    // 🌍 Appliquer la langue (FR / EN / ES uniquement)
    context.read<LocaleController>().setLocale(LocaleController.fromCode(code));

    // 🔙 Retour à la page paramètres
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.choose_language),
      ),
      body: ListView(
        children: [
          _langTile('fr', 'Français 🇫🇷'),
          _langTile('en', 'English 🇬🇧'),
          _langTile('es', 'Español 🇪🇸'),
        ],
      ),
    );
  }

  Widget _langTile(String code, String label) {
    return RadioListTile<String>(
      value: code,
      groupValue: _currentLang,
      title: Text(label),
      onChanged: (v) {
        if (v != null) {
          _changeLang(v);
        }
      },
    );
  }
}
