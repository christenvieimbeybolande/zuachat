import 'dart:convert';
import 'package:dio/dio.dart';
import 'client.dart';

Future<void> apiForgotVerifyCode(String email, String code) async {
  final dio = ApiClient.raw();

  final res = await dio.post(
    '/auth_forgot_verify_code.php',
    data: jsonEncode({'email': email, 'code': code}),
    options: Options(headers: {'Content-Type': 'application/json'}),
  );

  if (res.data['ok'] != true) {
    throw Exception(res.data['error']?['message'] ?? 'Code invalide.');
  }
}
