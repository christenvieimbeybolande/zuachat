import 'package:dio/dio.dart';
import 'client.dart';

/// 🏞️ Met à jour la photo de couverture
Future<Map<String, dynamic>> updateCoverPhoto(String path) async {
  final dio = await ApiClient.authed();

  try {
    print('📡 [UPDATE COVER] ➝ Upload /update_cover.php...');
    final formData = FormData.fromMap({
      'couverture': await MultipartFile.fromFile(path),
    });

    final res = await dio.post('/update_cover.php', data: formData);

    print('✅ [UPDATE COVER] Réponse ${res.statusCode}: ${res.data}');
    if (res.statusCode == 200 && res.data is Map) {
      return res.data as Map<String, dynamic>;
    } else {
      return {'success': false, 'message': 'Erreur de serveur'};
    }
  } on DioException catch (e) {
    print('❌ [UPDATE COVER] Erreur Dio: ${e.message}');
    return {'success': false, 'message': 'Erreur réseau'};
  } catch (e) {
    print('❌ [UPDATE COVER] Exception: $e');
    return {'success': false, 'message': e.toString()};
  }
}
