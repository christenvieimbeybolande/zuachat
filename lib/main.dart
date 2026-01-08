import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// 🔥 FIREBASE
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// 🔔 LOCAL NOTIFICATIONS (SON EN FOREGROUND)
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

/// 🔔 Local notifications instance
final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

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

  // 🔔 Init local notifications
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await localNotifications.initialize(initSettings);

  final prefs = await SharedPreferences.getInstance();
  await _migrateIfNeeded(prefs);

  final savedTheme = prefs.getString('theme') ?? 'light';
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
    debugPrint("♻️ Migration $storedVersion → $kAppVersion");
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
    _listenForegroundNotifications();
  }

  /// =========================================================
  /// 🔔 INIT FCM + ENVOI TOKEN BACKEND
  /// =========================================================
  Future<void> _initFCM() async {
    final fcm = FirebaseMessaging.instance;

    await fcm.requestPermission(alert: true, badge: true, sound: true);

    final token = await fcm.getToken();
    debugPrint("🔔 FCM TOKEN: $token");

    if (token != null) {
      await _sendFcmTokenToBackend(token);
    }
  }

  /// =========================================================
  /// 🔔 NOTIFICATION + SON EN FOREGROUND
  /// =========================================================
  void _listenForegroundNotifications() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notif = message.notification;
      if (notif == null) return;

      localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        notif.title ?? 'ZuaChat',
        notif.body ?? '',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'zuachat_default',
            'ZuaChat Notifications',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
          ),
        ),
      );
    });
  }

  /// =========================================================
  /// 🔗 ENVOI TOKEN AU BACKEND
  /// =========================================================
  Future<void> _sendFcmTokenToBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      if (accessToken == null || accessToken.isEmpty) return;

      await http.post(
        Uri.parse('https://zuachat.com/api/save_fcm_token.php'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fcm_token': token}),
      );
    } catch (e) {
      debugPrint("❌ Erreur envoi FCM: $e");
    }
  }

  /// =========================================================
  /// 🔐 CHECK LOGIN
  /// =========================================================
  Future<bool> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token')?.isNotEmpty == true &&
        prefs.getString('current_session_id')?.isNotEmpty == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final locale = context.watch<LocaleController>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "ZuaChat",
      locale: locale.locale,
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
      themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: FutureBuilder<bool>(
        future: _checkLogin(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(
                child: ZuaLoader(looping: true, size: 64),
              ),
            );
          }
          return snapshot.data! ? const FeedPage() : const LoginPage();
        },
      ),
    );
  }
}
