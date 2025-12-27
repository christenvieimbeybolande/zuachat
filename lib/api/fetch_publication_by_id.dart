import 'package:dio/dio.dart';
import 'client.dart';

/// ===========================================================
/// 📄 API - Récupérer une publication par ID
/// ===========================================================
Future<Map<String, dynamic>?> fetchPublicationById(int publicationId) async {
  try {
    final dio = await ApiClient.authed();

    final res = await dio.get(
      '/fetch_publication_by_id.php',
      queryParameters: {
        'publication_id': publicationId,
      },
    );

    if (res.statusCode == 200 &&
        res.data is Map &&
        res.data['success'] == true) {
      return Map<String, dynamic>.from(res.data['data']);
    }

    return null;
  } catch (_) {
    return null;
  }
}
