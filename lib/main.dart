import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🔥 FIREBASE
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// 🔔 LOCAL NOTIFICATIONS
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// 🌍 Localisation
import 'package:flutter_localizations/flutter_localizations.dart';
import 'gen_l10n/app_localizations.dart';

// 📄 Pages
import 'pages/login_page.dart';
import 'pages/feed_page.dart';
import 'pages/app_update_page.dart';

// 🎨 Thème
import 'theme/theme_controller.dart';

// 🔄 Loader
import 'widgets/zua_loader.dart';

// 🌐 API
import 'api/client.dart';
import 'api/app_update_check.dart';

/// 🔥 VERSION APP (AFFICHAGE UNIQUEMENT)
const String kAppVersion = "5.5.1";

/// 🔔 Local notifications instance
final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

/// =========================================================
/// 🔔 FCM BACKGROUND HANDLER (ANDROID SAFE)
/// =========================================================
@pragma('vm:entry-point')
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

  // 🔔 Local notifications
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );

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
/// 🔄 MIGRATION (NE TOUCHE PAS)
/// =========================================================
Future<void> _migrateIfNeeded(SharedPreferences prefs) async {
  final storedVersion = prefs.getString('app_version');

  if (storedVersion != kAppVersion) {
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
  bool _updateChecked = false;
  Widget? _forcedPage;

  @override
  void initState() {
    super.initState();
    _checkUpdate();
    _initFCM();
    _listenForegroundNotifications();
  }

  /// =========================================================
  /// 🔄 CHECK UPDATE (ANDROID ONLY)
  /// =========================================================
  Future<void> _checkUpdate() async {
    final data = await AppUpdateCheck.check();

    if (!mounted) return;

    if (data != null && data['update_required'] == true) {
      setState(() {
        _forcedPage = AppUpdatePage(
          message: data['message'],
          storeUrl: data['store_url'],
          force: data['force_update'] == true,
        );
        _updateChecked = true;
      });
    } else {
      setState(() => _updateChecked = true);
    }
  }

  /// =========================================================
  /// 🔔 INIT FCM
  /// =========================================================
  Future<void> _initFCM() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (Platform.isIOS) {
      String? apnsToken;
      for (int i = 0; i < 5; i++) {
        apnsToken = await messaging.getAPNSToken();
        if (apnsToken != null) break;
        await Future.delayed(const Duration(seconds: 1));
      }
      if (apnsToken == null) return;
    }

    final fcmToken = await messaging.getToken();
    if (fcmToken == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('access_token') == null) return;

    final dio = await ApiClient.authed();
    await dio.post("/save_fcm_token.php", data: {"fcm_token": fcmToken});
  }

  /// =========================================================
  /// 🔔 FOREGROUND NOTIFICATIONS
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
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    });
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

    if (!_updateChecked) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: ZuaLoader(looping: true, size: 64),
          ),
        ),
      );
    }

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
      home: _forcedPage ??
          FutureBuilder<bool>(
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
