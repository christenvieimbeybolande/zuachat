import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  bool _isDark;

  // =========================================================
  // 🔥 CONSTRUCTEUR
  // =========================================================
  ThemeController({bool initialDark = false}) : _isDark = initialDark;

  bool get isDark => _isDark;

  // =========================================================
  // 🌙 ACTIVER / DÉSACTIVER MODE SOMBRE
  // =========================================================
  Future<void> toggleTheme(bool value) async {
    if (_isDark == value) return;

    _isDark = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', value ? 'dark' : 'light');
  }

  // =========================================================
  // 🔄 CHARGER LE THÈME SAUVEGARDÉ
  // =========================================================
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('theme') ?? 'light';

    _isDark = savedTheme == 'dark';
    notifyListeners();
  }
}
