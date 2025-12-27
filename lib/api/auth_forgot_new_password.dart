import 'dart:convert';
import 'package:dio/dio.dart';
import 'client.dart';

Future<void> apiForgotNewPassword(
    String email, String code, String password) async {
  final dio = ApiClient.raw();

  final res = await dio.post(
    '/auth_forgot_new_password.php',
    data: jsonEncode({
      'email': email,
      'code': code,
      'password': password,
    }),
    options: Options(headers: {'Content-Type': 'application/json'}),
  );

  if (res.data['ok'] != true) {
    throw Exception(res.data['error']?['message'] ??
        'Impossible de changer le mot de passe.');
  }
}
