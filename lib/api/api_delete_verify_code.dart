import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'client.dart';

Future<void> apiDeleteVerifyCode(String code) async {
  final dio = ApiClient.raw(); // ❗ PAS authed()

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('access_token');

  if (token == null || token.isEmpty) {
    throw Exception('Session expirée');
  }

  try {
    final res = await dio.post(
      '/auth_delete_verify_code.php',
      data: jsonEncode({'code': code}),
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    if (res.data is Map && res.data['ok'] == true) return;

    throw Exception(res.data['error']?['message'] ?? 'Code invalide');
  } on DioException catch (e) {
    throw Exception(
      e.response?.data?['error']?['message'] ?? 'Erreur réseau',
    );
  }
}
