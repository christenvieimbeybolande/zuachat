import 'dart:convert';
import 'package:dio/dio.dart';

import 'client.dart'; // 🔥 même client que auth_login / auth_signup

// ============================================================
// 🔥 ENVOI DU CODE DE VÉRIFICATION PAR EMAIL
// ============================================================
Future<void> apiSendEmailCode(String email) async {
  final dio = ApiClient.raw();

  try {
    final res = await dio.post(
      '/auth_email_send_code.php',
      data: jsonEncode({'email': email}),
      options: Options(
        headers: {'Content-Type': 'application/json'},
      ),
    );

    final body = res.data;

    // 🔥 Sécurité : réponse invalide
    if (body == null || body is! Map) {
      throw Exception("Réponse serveur invalide.");
    }

    if (body['ok'] != true) {
      final msg =
          body['error']?['message'] ?? 'Erreur lors de l’envoi du code.';
      throw Exception(msg);
    }

    // ✅ Si on arrive ici → code envoyé
  } on DioException catch (e) {
    final statusCode = e.response?.statusCode;
    final msg =
        e.response?.data?['error']?['message'] ??
        "Erreur réseau ($statusCode)";
    throw Exception(msg);
  } catch (e) {
    throw Exception(e.toString().replaceFirst('Exception: ', ''));
  }
}

// ============================================================
// 🔥 VÉRIFICATION DU CODE EMAIL (CRITIQUE)
// ============================================================
Future<void> apiVerifyEmailCode(String email, String code) async {
  final dio = ApiClient.raw();

  try {
    final res = await dio.post(
      '/auth_email_verify_code.php',
      data: jsonEncode({
        'email': email,
        'code': code,
      }),
      options: Options(
        headers: {'Content-Type': 'application/json'},
      ),
    );

    final body = res.data;

    // 🔥🔥🔥 SÉCURITÉ ABSOLUE (évite spinner infini)
    if (body == null || body is! Map) {
      throw Exception("Réponse serveur invalide.");
    }

    // 🔥🔥🔥 LIGNE LA PLUS IMPORTANTE
    if (body['ok'] != true) {
      final msg =
          body['error']?['message'] ?? 'Code invalide ou expiré.';
      throw Exception(msg);
    }

    // ✅ SI ON ARRIVE ICI → CODE VALIDE
  } on DioException catch (e) {
    final statusCode = e.response?.statusCode;
    final msg =
        e.response?.data?['error']?['message'] ??
        "Erreur réseau ($statusCode)";
    throw Exception(msg);
  } catch (e) {
    throw Exception(e.toString().replaceFirst('Exception: ', ''));
  }
}
