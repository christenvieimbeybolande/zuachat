import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🌍 Localisation Flutter (gen_l10n)
import 'package:flutter_localizations/flutter_localizations.dart';
import 'gen_l10n/app_localizations.dart';

import 'pages/login_page.dart';
import 'pages/feed_page.dart';
import 'theme/theme_controller.dart';

// 🔥 Loader brandé
import 'widgets/zua_loader.dart';

/// 🔥 VERSION ACTUELLE DE L’APP
/// ⚠️ À incrémenter à CHAQUE mise à jour importante
const String kAppVersion = "3.5.0";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // =========================================================
  // 🔥 MIGRATION APRÈS MISE À JOUR (ANTI-BLOCAGE)
  // =========================================================
  await _migrateIfNeeded(prefs);

  // 🔥 Thème sauvegardé
  final savedTheme = prefs.getString('theme') ?? 'light';

  // 🌍 Langue sauvegardée
  final savedLang = prefs.getString('app_lang') ?? 'fr';

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeController(
            initialDark: savedTheme == 'dark',
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LocaleController(
            LocaleController.fromCode(savedLang),
          ),
        ),
      ],
      child: const ZuaChatApp(),
    ),
  );
}

/// =========================================================
/// 🔥 MIGRATION LOGIC
/// =========================================================
Future<void> _migrateIfNeeded(SharedPreferences prefs) async {
  final storedVersion = prefs.getString('app_version');

  if (storedVersion != kAppVersion) {
    debugPrint("♻️ Migration app $storedVersion → $kAppVersion");

    // 🧹 Nettoyage ciblé (sécurité + stabilité)
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('current_session_id');

    // 💾 Sauvegarde version
    await prefs.setString('app_version', kAppVersion);
  }
}

/// =========================================================
/// 🌍 CONTROLLER LANGUE (FR / EN / ES)
/// =========================================================
class LocaleController extends ChangeNotifier {
  Locale _locale;

  LocaleController(this._locale);

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }

  static Locale fromCode(String code) {
    switch (code) {
      case 'en':
        return const Locale('en');
      case 'es':
        return const Locale('es');
      case 'fr':
      default:
        return const Locale('fr');
    }
  }
}

class ZuaChatApp extends StatelessWidget {
  const ZuaChatApp({super.key});

  // =========================================================
  // 🔐 CHECK LOGIN (TOKEN + SESSION)
  // =========================================================
  Future<bool> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final session = prefs.getString('current_session_id');

    if (token == null || token.isEmpty) return false;
    if (session == null || session.isEmpty) return false;

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final localeController = context.watch<LocaleController>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "ZuaChat",

      // =========================================================
      // 🌍 INTERNATIONALISATION
      // =========================================================
      locale: localeController.locale,
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
        Locale('es'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // ================= THEME CLAIR =================
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF0000),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFF0000),
          foregroundColor: Colors.white,
        ),
      ),

      // ================= THEME SOMBRE =================
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF18191A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF0000),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFF0000),
          foregroundColor: Colors.white,
        ),
      ),

      // 🌙 MODE ACTIF
      themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,

      // ================= HOME =================
      home: FutureBuilder<bool>(
        future: _checkLogin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: ZuaLoader(
                  looping: true,
                  size: 64,
                ),
              ),
            );
          }

          return snapshot.data == true ? const FeedPage() : const LoginPage();
        },
      ),

      // ================= ROUTES =================
      routes: {
        '/login': (_) => const LoginPage(),
        '/feed': (_) => const FeedPage(),
      },
    );
  }
}
