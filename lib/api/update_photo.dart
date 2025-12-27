import 'package:dio/dio.dart';
import 'client.dart';

/// 🖼️ Met à jour la photo de profil
Future<Map<String, dynamic>> updateProfilePhoto(String path) async {
  final dio = await ApiClient.authed();

  try {
    print('📡 [UPDATE PHOTO] ➝ Upload /update_photo.php...');
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(path),
    });

    final res = await dio.post('/update_photo.php', data: formData);

    print('✅ [UPDATE PHOTO] Réponse ${res.statusCode}: ${res.data}');
    if (res.statusCode == 200 && res.data is Map) {
      return res.data as Map<String, dynamic>;
    } else {
      return {'success': false, 'message': 'Erreur de serveur'};
    }
  } on DioException catch (e) {
    print('❌ [UPDATE PHOTO] Erreur Dio: ${e.message}');
    return {'success': false, 'message': 'Erreur réseau'};
  } catch (e) {
    print('❌ [UPDATE PHOTO] Exception: $e');
    return {'success': false, 'message': e.toString()};
  }
}
