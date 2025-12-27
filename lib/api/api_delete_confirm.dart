import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'client.dart';

Future<void> apiDeleteConfirm() async {
  final dio = ApiClient.raw(); // ❗ PAS authed()

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('access_token');

  if (token == null || token.isEmpty) {
    throw Exception('Session expirée');
  }

  try {
    final res = await dio.post(
      '/auth_delete_confirm.php',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    if (res.data is Map && res.data['ok'] == true) return;

    throw Exception(res.data['error']?['message'] ?? 'Erreur');
  } on DioException catch (e) {
    throw Exception(
      e.response?.data?['error']?['message'] ?? 'Erreur réseau',
    );
  }
}
