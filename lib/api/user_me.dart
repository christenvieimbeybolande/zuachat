import 'package:dio/dio.dart';
import 'client.dart';

/// 📡 Récupère les infos de l'utilisateur connecté
Future<Map<String, dynamic>> apiMe() async {
  final dio = await ApiClient.authed();

  try {
    final Response res = await dio.get('/user_me.php');
    final body = res.data;

    if (body['ok'] != true) {
      final msg = body['error'] ?? 'Erreur lors de la récupération du profil';
      throw Exception(msg);
    }

    // ✅ Accès direct au champ "user" de la réponse JSON
    return Map<String, dynamic>.from(body['user']);
  } on DioException catch (e) {
    print('❌ [API ME] Erreur Dio');
    print('URL: ${e.requestOptions.uri}');
    print('Code: ${e.response?.statusCode}');
    print('Body: ${e.response?.data}');
    print('Message: ${e.message}');

    final msg = e.response?.data?['error'] ??
        'Erreur réseau (${e.response?.statusCode ?? 'inconnue'})';
    throw Exception(msg);
  } catch (e) {
    print('❌ [API ME] Erreur inconnue: $e');
    throw Exception('Erreur: $e');
  }
}
