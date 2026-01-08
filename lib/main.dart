import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// 🔥 FIREBASE
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// 🌍 Localisation
import 'package:flutter_localizations/flutter_localizations.dart';
import 'gen_l10n/app_localizations.dart';

// 📄 Pages
import 'pages/login_page.dart';
import 'pages/feed_page.dart';

// 🎨 Thème
import 'theme/theme_controller.dart';

// 🔄 Loader
import 'widgets/zua_loader.dart';

/// 🔥 VERSION ACTUELLE
const String kAppVersion = "3.5.0";

/// =========================================================
/// 🔔 FCM BACKGROUND HANDLER
/// =========================================================
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// =========================================================
/// 🚀 MAIN
/// =========================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Firebase
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  final prefs = await SharedPreferences.getInstance();

  // 🔄 Migration
  await _migrateIfNeeded(prefs);

  // 🎨 Thème
  final savedTheme = prefs.getString('theme') ?? 'light';

  // 🌍 Langue
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
/// 🔄 MIGRATION
/// =========================================================
Future<void> _migrateIfNeeded(SharedPreferences prefs) async {
  final storedVersion = prefs.getString('app_version');

  if (storedVersion != kAppVersion) {
    debugPrint("♻️ Migration app $storedVersion → $kAppVersion");

    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('current_session_id');

    await prefs.setString('app_version', kAppVersion);
  }
}

/// =========================================================
/// 🌍 CONTROLLER LANGUE
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

/// =========================================================
/// 📱 APP
/// =========================================================
class ZuaChatApp extends StatefulWidget {
  const ZuaChatApp({super.key});

  @override
  State<ZuaChatApp> createState() => _ZuaChatAppState();
}

class _ZuaChatAppState extends State<ZuaChatApp> {
  @override
  void initState() {
    super.initState();
    _initFCM();
  }

  /// =========================================================
  /// 🔔 INIT FCM + ENVOI TOKEN BACKEND
  /// =========================================================
  Future<void> _initFCM() async {
    final FirebaseMessaging fcm = FirebaseMessaging.instance;

    // Permission (Android 13+)
    await fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await fcm.getToken();
    debugPrint("🔔 FCM TOKEN: $token");

    if (token != null) {
      await _sendFcmTokenToBackend(token);
    }
  }

  /// =========================================================
  /// 🔗 ENVOI TOKEN AU BACKEND
  /// =========================================================
  Future<void> _sendFcmTokenToBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      if (accessToken == null || accessToken.isEmpty) {
        debugPrint("ℹ️ Pas connecté → token non envoyé");
        return;
      }

      final res = await http.post(
        Uri.parse('https://zuachat.com/api/save_fcm_token.php'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'fcm_token': token,
        }),
      );

      debugPrint("📤 FCM envoyé (${res.statusCode})");
    } catch (e) {
      debugPrint("❌ Erreur envoi FCM: $e");
    }
  }

  /// =========================================================
  /// 🔐 CHECK LOGIN
  /// =========================================================
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

      // 🌍 Langue
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

      // ☀️ Thème clair
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

      // 🌙 Thème sombre
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

      themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,

      // 🏠 HOME
      home: FutureBuilder<bool>(
        future: _checkLogin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: ZuaLoader(looping: true, size: 64),
              ),
            );
          }

          return snapshot.data == true
              ? const FeedPage()
              : const LoginPage();
        },
      ),

      routes: {
        '/login': (_) => const LoginPage(),
        '/feed': (_) => const FeedPage(),
      },
    );
  }
}
