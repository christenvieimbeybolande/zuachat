import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'client.dart';

/// 🔵 Requête API d’inscription (simple + pro)
Future<void> apiSignup(Map<String, dynamic> data) async {
  final dio = ApiClient.raw();

  try {
    final res = await dio.post(
      '/auth_signup.php',   // ou ton fichier PHP d'inscription
      data: jsonEncode(data),
      options: Options(
        headers: {'Content-Type': 'application/json'},
      ),
    );

    final body = res.data;

    // ❌ Erreur retournée par API
    if (body['ok'] != true) {
      final msg = body['error']?['message'] ?? 'Erreur inscription';
      throw Exception(msg);
    }

    final d = body['data'];

    final access = d['access_token'];
    final refresh = d['refresh_token'];
    final sessionId = d['session_id'];

    if (access == null || refresh == null || sessionId == null) {
      throw Exception("Réponse serveur invalide (missing tokens)");
    }

    // ============================================================
    // 🔐 1. Sauvegarde des tokens (connexion automatique)
    // ============================================================
    await saveTokens(access, refresh);

    // ============================================================
    // 💾 2. Sauvegarde de la session courante
    // ============================================================
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_session_id', sessionId);

    // Optionnel mais utile :
    if (d['type_compte'] != null) {
      await prefs.setString('type_compte', d['type_compte']);
    }

    if (d['user'] != null) {
      await prefs.setString('user_data', jsonEncode(d['user']));
    }

  } on DioException catch (e) {
    final msg = e.response?.data?['error']?['message'] ??
        'Erreur réseau (DioException)';
    throw Exception(msg);
  } catch (e) {
    throw Exception(e.toString().replaceFirst("Exception: ", ""));
  }
}
