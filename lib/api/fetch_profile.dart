import 'package:dio/dio.dart';
import 'client.dart';

/// 🔹 Récupère le profil complet de l’utilisateur connecté
Future<Map<String, dynamic>> fetchProfile() async {
  final dio = await ApiClient.authed();

  try {
    print('📡 [PROFILE] ➝ Appel API /fetch_profile.php...');
    final res = await dio.get('/fetch_profile.php');

    print('✅ [PROFILE] Réponse ${res.statusCode}: ${res.data}');
    if (res.statusCode == 200 && res.data is Map) {
      // Conversion propre en Map<String, dynamic>
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(res.data as Map);
      return data;
    } else {
      return {'success': false, 'message': 'Réponse inattendue du serveur'};
    }
  } on DioException catch (e) {
    print('❌ [PROFILE] Erreur réseau: ${e.message}');
    return {'success': false, 'message': 'Erreur de connexion réseau'};
  } catch (e) {
    print('❌ [PROFILE] Exception: $e');
    return {'success': false, 'message': e.toString()};
  }
}
