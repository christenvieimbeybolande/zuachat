import 'dart:convert';
import 'package:dio/dio.dart';

import 'client.dart'; // 🔥 même client que auth_login / auth_signup

/// Envoi du code de vérification à l'email
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

    if (body['ok'] != true) {
      final msg =
          body['error']?['message'] ?? 'Erreur lors de l’envoi du code.';
      throw Exception(msg);
    }
  } on DioException catch (e) {
    final statusCode = e.response?.statusCode;
    final msg =
        e.response?.data?['error']?['message'] ?? "Erreur réseau ($statusCode)";
    throw Exception(msg);
  } catch (e) {
    throw Exception(e.toString().replaceFirst('Exception: ', ''));
  }
}

/// Vérification du code
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

    if (body['ok'] != true) {
      final msg = body['error']?['message'] ?? 'Code invalide ou expiré.';
      throw Exception(msg);
    }
  } on DioException catch (e) {
    final statusCode = e.response?.statusCode;
    final msg =
        e.response?.data?['error']?['message'] ?? "Erreur réseau ($statusCode)";
    throw Exception(msg);
  } catch (e) {
    throw Exception(e.toString().replaceFirst('Exception: ', ''));
  }
}
