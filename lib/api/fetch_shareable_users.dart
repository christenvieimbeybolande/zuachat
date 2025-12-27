import 'package:dio/dio.dart';
import 'client.dart';

/// ===========================================================
/// 👥 API - Liste des utilisateurs partageables
/// ===========================================================
Future<List<Map<String, dynamic>>> fetchShareableUsers() async {
  try {
    final dio = await ApiClient.authed();

    final res = await dio.get('/fetch_shareable_users.php');

    if (res.statusCode == 200 &&
        res.data is Map &&
        res.data['success'] == true) {
      return List<Map<String, dynamic>>.from(res.data['data']);
    }

    return [];
  } on DioException {
    return [];
  } catch (_) {
    return [];
  }
}
