import 'package:dio/dio.dart';
import 'client.dart'; // ✅ on garde ton client centralisé ApiClient

/// ===========================================================
/// 💬 API - Réactions sur les commentaires (❤️ 👍 😂 😮)
/// ===========================================================
/// Endpoint : /api/react_comment.php
/// Authentification JWT obligatoire
/// ===========================================================

/// 🟢 Réagir à un commentaire (ajouter / modifier / retirer)
/// Si l'utilisateur clique sur le même emoji → supprime la réaction.
/// Si il choisit un autre → met à jour.
/// Si aucune réaction avant → ajoute.
/// Retourne un message clair du backend.
Future<Map<String, dynamic>> apiReactToComment({
  required int commentId,
  required String emoji,
}) async {
  final dio = await ApiClient.authed(); // ✅ même logique que comments.dart

  try {
    final res = await dio.post(
      '/react_comment.php',
      data: FormData.fromMap({
        'comment_id': commentId,
        'emoji': emoji,
      }),
    );

    // ✅ Sécurisation : vérifier que res.data est bien une Map
    final data = (res.data is Map) ? res.data as Map : {};

    final bool success =
        data['success'] == true || data['ok'] == true || res.statusCode == 200;

    return {
      'success': success,
      'message': data['message'] ??
          (success ? 'Réaction enregistrée' : 'Erreur serveur'),
      'emoji': data['emoji'] ?? emoji,
    };
  } on DioException catch (e) {
    print('❌ [apiReactToComment] DioException: ${e.message}');
    final status = e.response?.statusCode ?? '???';
    return {
      'success': false,
      'message': 'Erreur réseau ($status) : ${e.message}',
    };
  } catch (e) {
    print('❌ [apiReactToComment] Exception: $e');
    return {
      'success': false,
      'message': e.toString(),
    };
  }
}
