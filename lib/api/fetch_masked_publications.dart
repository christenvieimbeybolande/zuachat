import 'package:dio/dio.dart';
import 'client.dart';

Future<Map<String, dynamic>> fetchMaskedPublications() async {
  final dio = await ApiClient.authed();
  try {
    final res = await dio.get('/fetch_masked_publications.php');
    if (res.statusCode == 200 && res.data['success'] == true) {
      return res.data;
    }
    return {
      'success': false,
      'message': res.data['message'] ?? 'Erreur serveur'
    };
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}
