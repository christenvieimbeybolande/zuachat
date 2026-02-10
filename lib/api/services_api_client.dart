import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServicesApiClient {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://zuadevi.zuachat.com/api',
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  static Future<Dio> authed() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token'); // token ZuaChat

    if (token == null || token.isEmpty) {
      throw Exception('Token ZuaChat manquant');
    }

    _dio.options.headers['Authorization'] = 'Bearer $token';
    return _dio;
  }
}
