import 'package:dio/dio.dart';
import 'client.dart'; // ✅ ton client Dio centralisé

/// ===========================================================
/// 💬 API - Réactions sur les publications (❤️ 👍 😂 😮)
/// ===========================================================
/// Endpoint : /api/react_publication.php
/// Authentification JWT obligatoire
/// ===========================================================

Future<Map<String, dynamic>> apiReactToPublication({
  required int publicationId,
  required String emoji,
}) async {
  final dio = await ApiClient.authed(); // ✅ client Dio avec token JWT

  try {
    final res = await dio.post(
      '/react_publication.php',
      data: FormData.fromMap({
        'publication_id': publicationId,
        'emoji': emoji,
      }),
    );

    // ✅ Vérification et extraction sécurisée
    final data = (res.data is Map) ? res.data as Map<String, dynamic> : {};
    final bool success =
        data['success'] == true || data['ok'] == true || res.statusCode == 200;

    return {
      'success': success,
      'message': data['message'] ?? 'Réaction effectuée',
      'removed': data['removed'] ?? false,
      'emoji': data['emoji'] ?? emoji,
      'reactions': data['reactions'] ?? [],
      'count': data['count'] ?? 0,
    };
  } on DioException catch (e) {
    print('❌ [apiReactToPublication] DioException: ${e.message}');
    final status = e.response?.statusCode ?? '???';
    return {
      'success': false,
      'message': 'Erreur réseau ($status) : ${e.message}',
    };
  } catch (e) {
    print('❌ [apiReactToPublication] Exception: $e');
    return {
      'success': false,
      'message': e.toString(),
    };
  }
}
