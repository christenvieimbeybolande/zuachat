import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/env.dart';

class ApiClient {
  static Dio? _client;
  static bool _interceptorsAdded = false;

  // ===========================================================================
  // RESET COMPLET
  // ===========================================================================
  static Future<void> reset() async {
    print("♻️ ApiClient reset()");
    _client = null;
    _interceptorsAdded = false;
  }

  // ===========================================================================
  // CRÉATION DIO
  // ===========================================================================
  static Dio _createClient() {
    return Dio(
      BaseOptions(
        baseUrl: Env.apiBase,

        // ⏳ TEMPS LONG POUR UPLOAD (IMPORTANT)
        connectTimeout: const Duration(minutes: 1),
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 5),

        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  // ===========================================================================
  // CLIENT PUBLIC (identique à l'ancien)
  // ===========================================================================
  static Dio raw() {
    _client = _createClient();
    _client!.interceptors.clear();
    _client!.interceptors.add(_loggingInterceptor());
    return _client!;
  }

  // ===========================================================================
  // CLIENT AUTHENTIFIÉ (optimisé mais 100% compatible)
  // ===========================================================================
  static Future<Dio> authed() async {
    if (_client == null) {
      _client = _createClient();
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final sessionId = prefs.getString('current_session_id');

    // Mettre les headers
    _client!.options.headers['Authorization'] =
        (token != null && token.isNotEmpty) ? "Bearer $token" : "";
    _client!.options.headers['X-Session-Id'] = sessionId ?? "";

    // 🔥 NE PAS vider les interceptors → sinon ça casse les anciennes pages
    // On ajoute les interceptors UNE SEULE FOIS
    if (!_interceptorsAdded) {
      _client!.interceptors.clear();
      _client!.interceptors.add(_loggingInterceptor());
      _client!.interceptors.add(_authInterceptor());
      _interceptorsAdded = true;
    }

    return _client!;
  }

  // ===========================================================================
  // INTERCEPTOR AUTH
  // ===========================================================================
  static InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onResponse: (res, handler) async {
        // Pour compatibilité totale avec les anciennes pages
        if (res.data is Map && res.data['logout_required'] == true) {
          print("🔴 logout_required → logoutLocal()");
          await logoutLocal();
        }
        return handler.next(res);
      },
      onError: (DioException e, handler) async {
        final res = e.response;

        // Session révoquée par le serveur WEB
        if (res?.statusCode == 401 &&
            res?.data is Map &&
            res!.data['error'] == 'SESSION_REVOKED') {
          print("🔴 SESSION_REVOKED → logoutLocal()");
          await logoutLocal();
          return handler.next(e);
        }

        // Token expiré → refresh
        if (res?.statusCode == 401) {
          print("⚠️ Token expiré → refresh_token");

          final ok = await _tryRefreshToken();
          if (ok) {
            final newToken = await _getAccessToken();
            e.requestOptions.headers['Authorization'] = "Bearer $newToken";

            // Retry propre
            final retry = await _client!.fetch(e.requestOptions);
            return handler.resolve(retry);
          }

          print("❌ Refresh échoué → logout");
          await clearTokens();
          await reset();
        }

        return handler.next(e);
      },
    );
  }

  // ===========================================================================
  // LOGGING
  // ===========================================================================
  static InterceptorsWrapper _loggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (opt, handler) {
        print("➡️ ${opt.method} ${opt.uri}");
        return handler.next(opt);
      },
      onResponse: (res, handler) {
        print("✅ ${res.statusCode} ${res.realUri}");
        return handler.next(res);
      },
      onError: (err, handler) {
        print("❌ ERROR ${err.response?.statusCode}");
        return handler.next(err);
      },
    );
  }

  // ===========================================================================
  // REFRESH TOKEN
  // ===========================================================================
  static Future<bool> _tryRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refresh = prefs.getString('refresh_token');
      if (refresh == null) return false;

      final dio = Dio();
      final res = await dio.post(
        '${Env.apiBase}/refresh_token.php',
        options: Options(headers: {'Authorization': 'Bearer $refresh'}),
      );

      if (res.data['ok'] == true) {
        await saveTokens(
          res.data['data']['access_token'],
          res.data['data']['refresh_token'],
        );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // ===========================================================================
  // DOWNLOAD FILES
  // ===========================================================================
  static Future<File> downloadTempFile(String url) async {
    final dio = Dio();

    final tempDir = await getTemporaryDirectory();
    final filename = "zuachat_${DateTime.now().millisecondsSinceEpoch}.jpg";

    final file = File("${tempDir.path}/$filename");

    final response = await dio.get(
      url,
      options: Options(responseType: ResponseType.bytes),
    );

    await file.writeAsBytes(response.data);

    return file;
  }

  // ===========================================================================
  // LOGOUT
  // ===========================================================================
  static Future<void> logoutLocal() async {
    print("🧹 logoutLocal()");
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('current_session_id');
    await reset();
  }
}

// ============================================================================
// SAVE TOKENS
// ============================================================================
Future<void> saveTokens(String access, [String? refresh]) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('access_token', access);
  if (refresh != null) prefs.setString('refresh_token', refresh);
}

// ============================================================================
// CLEAR TOKENS
// ============================================================================
Future<void> clearTokens() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('access_token');
  await prefs.remove('refresh_token');
  await prefs.remove('current_session_id');
}
