import 'dart:convert';
import 'package:dio/dio.dart';
import 'client.dart';

Future<int> apiForgotSendCode(String email) async {
  final dio = ApiClient.raw();

  try {
    final res = await dio.post(
      '/auth_forgot_send_code.php',
      data: jsonEncode({'email': email}),
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    final body = res.data;

    if (body['ok'] != true) {
      throw Exception(body['error']?['message'] ?? 'Erreur envoi du code.');
    }

    return body['data']?['expires_in'] ?? 120;
  } catch (e) {
    throw Exception("Erreur réseau ou serveur.");
  }
}
