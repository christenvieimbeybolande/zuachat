import 'package:dio/dio.dart';
import 'client.dart';

/// Enregistre une publication dans un dossier
Future<Map<String, dynamic>> savePublication({
  required int publicationId,
  required int folderId,
}) async {
  final dio = await ApiClient.authed();

  try {
    final res = await dio.post('/save_publication.php', data: {
      'publication_id': publicationId,
      'folder_id': folderId,
    });

    if (res.statusCode == 200 && res.data is Map) {
      return Map<String, dynamic>.from(res.data);
    } else {
      return {'success': false, 'message': 'Réponse invalide du serveur'};
    }
  } on DioException catch (e) {
    return {
      'success': false,
      'message': e.response?.data?['message'] ??
          'Erreur réseau : ${e.message ?? 'inconnue'}'
    };
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}
