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
        connectTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 2),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  // ===========================================================================
  // CLIENT PUBLIC (non authentifié)
  // ===========================================================================
  static Dio raw() {
    final dio = _createClient();
    dio.interceptors.add(_loggingInterceptor());
    return dio;
  }

  // ===========================================================================
  // CLIENT AUTHENTIFIÉ (JWT ONLY)
  // ===========================================================================
  static Future<Dio> authed() async {
    if (_client == null) {
      _client = _createClient();
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    _client!.options.headers['Authorization'] =
        (token != null && token.isNotEmpty) ? "Bearer $token" : "";

    if (!_interceptorsAdded) {
      _client!.interceptors.clear();
      _client!.interceptors.add(_loggingInterceptor());
      _client!.interceptors.add(_authInterceptor());
      _interceptorsAdded = true;
    }

    return _client!;
  }

  // ===========================================================================
  // INTERCEPTOR AUTH (AUTO REFRESH)
  // ===========================================================================
  static InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onError: (DioException e, handler) async {
        final res = e.response;

        // Token expiré → tentative refresh
        if (res?.statusCode == 401) {
          print("⚠️ 401 → tentative refresh_token");

          final refreshed = await _tryRefreshToken();
          if (refreshed) {
            final newToken = await _getAccessToken();
            if (newToken != null) {
              e.requestOptions.headers['Authorization'] =
                  "Bearer $newToken";

              try {
                final retry = await _client!.fetch(e.requestOptions);
                return handler.resolve(retry);
              } catch (_) {
                // fallback logout
              }
            }
          }

          print("❌ Refresh échoué → logout");
          await logoutLocal();
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
  // REFRESH TOKEN (BODY JSON)
  // ===========================================================================
  static Future<bool> _tryRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refresh = prefs.getString('refresh_token');
      if (refresh == null || refresh.isEmpty) return false;

      final dio = Dio(BaseOptions(
        baseUrl: Env.apiBase,
        headers: const {'Content-Type': 'application/json'},
      ));

      final res = await dio.post(
        '/refresh_token.php',
        data: {'refresh_token': refresh},
      );

      if (res.data is Map && res.data['ok'] == true) {
        final data = res.data['data'] ?? {};
        await saveTokens(
          data['access_token'],
          data['refresh_token'],
        );
        return true;
      }
      return false;
    } catch (e) {
      print("❌ Refresh exception: $e");
      return false;
    }
  }

  static Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // ===========================================================================
  // DOWNLOAD FILE
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
  // LOGOUT LOCAL
  // ===========================================================================
  static Future<void> logoutLocal() async {
    print("🧹 logoutLocal()");
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await reset();
  }
}

// ============================================================================
// SAVE TOKENS
// ============================================================================
Future<void> saveTokens(String access, [String? refresh]) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('access_token', access);
  if (refresh != null && refresh.isNotEmpty) {
    await prefs.setString('refresh_token', refresh);
  }
}

// ============================================================================
// CLEAR TOKENS
// ============================================================================
Future<void> clearTokens() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('access_token');
  await prefs.remove('refresh_token');
}
