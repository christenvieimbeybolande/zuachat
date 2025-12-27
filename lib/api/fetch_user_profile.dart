import 'package:dio/dio.dart';
import 'client.dart';

/// 📡 Récupère le profil public d’un utilisateur (autre que soi)
Future<Map<String, dynamic>> fetchUserProfile(int userId) async {
  final dio = await ApiClient.authed();

  try {
    print('📡 [USER PROFILE] ➝ Appel API /fetch_user_profile.php?id=$userId...');
    final res = await dio.get(
      '/fetch_user_profile.php',
      queryParameters: {'id': userId},
    );

    print('✅ [USER PROFILE] Réponse ${res.statusCode}: ${res.data}');
    if (res.statusCode == 200 && res.data is Map) {
      return res.data as Map<String, dynamic>;
    } else {
      return {'success': false, 'message': 'Erreur inattendue du serveur'};
    }
  } on DioException catch (e) {
    print('❌ [USER PROFILE] Erreur Dio: ${e.message}');
    return {'success': false, 'message': 'Erreur de connexion réseau'};
  } catch (e) {
    print('❌ [USER PROFILE] Exception: $e');
    return {'success': false, 'message': e.toString()};
  }
}
