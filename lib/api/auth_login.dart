import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'client.dart';

/// 📦 Modèle de résultat de connexion
class LoginResult {
  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic> user;
  final String? specialCode;

  LoginResult(this.accessToken, this.refreshToken, this.user,
      {this.specialCode});
}

/// 🔐 Requête API de connexion
Future<LoginResult> apiLogin(String email, String password) async {
  final dio = ApiClient.raw();

  try {
    final res = await dio.post(
      '/auth_login.php',
      data: jsonEncode({
        'email': email,
        'password': password,
      }),
      options: Options(
        headers: {'Content-Type': 'application/json'},
      ),
    );

    final body = res.data;

    // ❌ Erreur retournée par l'API
    if (body['ok'] != true) {
      final errMsg = body['error']?['message'] ?? 'Erreur de connexion';
      throw Exception(errMsg);
    }

    final data = body['data'];

    // ===================================
    // 🔐 Sauvegarder Tokens
    // ===================================
    await saveTokens(data['access_token'], data['refresh_token']);

    // ===================================
    // 💾 Sauvegarder session + user_id
    // ===================================
    final prefs = await SharedPreferences.getInstance();

    if (data['session_id'] != null) {
      await prefs.setString('current_session_id', data['session_id']);
      print("💾 current_session_id enregistré : ${data['session_id']}");
    }

    if (data['device_type'] != null) {
      await prefs.setString('device_type', data['device_type']);
    }

    if (data['ip_address'] != null) {
      await prefs.setString('last_ip', data['ip_address']);
    }

    // ===================================
    // ⭐ CORRECTION : SAUVEGARDER L’ID UTILISATEUR
    // ===================================
    if (data['user'] != null &&
        data['user']['id'] != null &&
        data['user']['id'].toString().isNotEmpty) {
      await prefs.setString('user_id', data['user']['id'].toString());
      print("💾 USER_ID enregistré : ${data['user']['id']}");
    } else {
      print("❌ ERREUR: user_id absent dans la réponse API");
    }

    return LoginResult(
      data['access_token'],
      data['refresh_token'],
      Map<String, dynamic>.from(data['user']),
    );
  } on DioException catch (e) {
    final statusCode = e.response?.statusCode;
    final serverMsg = e.response?.data?['error']?['message'];

    // 🔥 CAS : compte en suppression
    if (statusCode == 403 && serverMsg != null) {
      throw Exception(serverMsg);
    }

    throw Exception(
      serverMsg ?? "Erreur réseau ($statusCode)",
    );
  }
}
