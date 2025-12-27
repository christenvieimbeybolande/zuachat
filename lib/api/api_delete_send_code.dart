import 'dart:convert';
import 'package:dio/dio.dart';
import 'client.dart';

/// 🔥 Envoie le code de confirmation pour suppression du compte
Future<int> apiDeleteSendCode(String password) async {
  final dio = await ApiClient.authed(); // ✅ OBLIGATOIRE

  try {
    print('📡 [DELETE] ➝ Envoi code suppression...');
    final res = await dio.post(
      '/auth_delete_send_code.php',
      data: jsonEncode({'password': password}),
      options: Options(headers: {
        'Content-Type': 'application/json',
      }),
    );

    print('✅ [DELETE] Réponse ${res.statusCode}: ${res.data}');

    if (res.data is Map && res.data['ok'] == true) {
      return res.data['data']?['expires_in'] ?? 120;
    } else {
      throw Exception(res.data['error']?['message'] ?? 'Erreur serveur');
    }
  } on DioException catch (e) {
    print('❌ [DELETE] Erreur Dio: ${e.message}');
    throw Exception(
      e.response?.data?['error']?['message'] ?? 'Erreur réseau',
    );
  }
}
