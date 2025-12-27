import 'package:dio/dio.dart';
import 'client.dart';

/// ===========================================================
/// 🔁 API - Partager une publication à un utilisateur
/// ===========================================================
Future<Map<String, dynamic>> sharePublication({
  required int publicationId,
  required int receiverId,
}) async {
  try {
    final dio = await ApiClient.authed();

    final res = await dio.post(
      '/share_publication.php',
      data: {
        'publication_id': publicationId,
        'receiver_id': receiverId,
      },
    );

    if (res.statusCode == 200 && res.data is Map) {
      return Map<String, dynamic>.from(res.data);
    }

    return {
      'success': false,
      'message': 'Réponse serveur invalide',
    };
  } on DioException catch (e) {
    return {
      'success': false,
      'message': e.response?.data?['message'] ?? e.message,
    };
  } catch (e) {
    return {
      'success': false,
      'message': 'Erreur interne : $e',
    };
  }
}
