import 'package:dio/dio.dart';
import 'client.dart';

/// 🧠 Met à jour la bio de l'utilisateur connecté
Future<Map<String, dynamic>> updateBio(String bio) async {
  final dio = await ApiClient.authed();

  try {
    print('📡 [UPDATE BIO] ➝ Appel API /update_bio.php...');
    final res = await dio.post(
      '/update_bio.php',
      data: {'bio': bio},
    );

    print('✅ [UPDATE BIO] Réponse ${res.statusCode}: ${res.data}');
    if (res.statusCode == 200 && res.data is Map) {
      return res.data as Map<String, dynamic>;
    } else {
      return {'success': false, 'message': 'Erreur inattendue du serveur'};
    }
  } on DioException catch (e) {
    print('❌ [UPDATE BIO] Erreur Dio: ${e.message}');
    return {'success': false, 'message': 'Erreur de connexion réseau'};
  } catch (e) {
    print('❌ [UPDATE BIO] Exception: $e');
    return {'success': false, 'message': e.toString()};
  }
}
