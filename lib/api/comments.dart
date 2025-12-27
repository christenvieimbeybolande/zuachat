import 'package:dio/dio.dart';
import 'client.dart'; // ✅ Ton client centralisé ApiClient

/// ===========================================================
/// 💬 API - Gestion des commentaires ZuaChat
/// ===========================================================
/// Fichiers cibles côté serveur :
///   - /api/comments.php
///   - /api/edit_comment.php
///   - /api/delete_comment.php
/// ===========================================================

/// 🟢 GET → Récupérer la liste des commentaires d’une publication
Future<List<dynamic>> apiFetchComments(int publicationId) async {
  final dio = await ApiClient.authed(); // Client avec Bearer token

  try {
    final res = await dio.get(
      '/comments.php', // ✅ chemin corrigé
      queryParameters: {'publication_id': publicationId},
    );

    if (res.data['success'] == true || res.data['ok'] == true) {
      return res.data['data'] ?? [];
    } else {
      throw Exception(res.data['message'] ?? 'Erreur serveur');
    }
  } on DioException catch (e) {
    print('❌ [apiFetchComments] Erreur réseau : ${e.message}');
    throw Exception(
      'Erreur réseau (${e.response?.statusCode ?? "?"}) : ${e.message}',
    );
  }
}

/// 🟠 POST → Ajouter un commentaire ou une réponse
Future<Map<String, dynamic>> apiAddComment({
  required int publicationId,
  required String texte,
  int? parentId,
}) async {
  final dio = await ApiClient.authed();

  try {
    final data = FormData.fromMap({
      'texte': texte,
      if (parentId != null) 'parent_id': parentId,
    });

    final res = await dio.post(
      '/comments.php?publication_id=$publicationId', // ✅ corrigé aussi
      data: data,
    );

    if (res.data['success'] == true || res.data['ok'] == true) {
      return {
        'success': true,
        'message': res.data['message'] ?? 'Commentaire ajouté',
      };
    } else {
      throw Exception(res.data['message'] ?? 'Erreur d’envoi');
    }
  } on DioException catch (e) {
    print('❌ [apiAddComment] Erreur réseau : ${e.message}');
    throw Exception('Erreur réseau : ${e.message}');
  }
}

/// ✏️ PUT → Modifier un commentaire existant
Future<Map<String, dynamic>> apiEditComment({
  required int commentId,
  required String texte,
}) async {
  final dio = await ApiClient.authed();

  try {
    final data = FormData.fromMap({
      'id': commentId,
      'texte': texte,
    });

    final res = await dio.post('/edit_comment.php', data: data); // ✅

    if (res.data['success'] == true || res.data['ok'] == true) {
      return {
        'success': true,
        'message': res.data['message'] ?? 'Commentaire modifié',
      };
    } else {
      throw Exception(res.data['message'] ?? 'Erreur modification');
    }
  } on DioException catch (e) {
    print('❌ [apiEditComment] ${e.message}');
    throw Exception('Erreur réseau : ${e.message}');
  }
}

/// 🗑️ DELETE → Supprimer un commentaire (et ses réponses)
Future<Map<String, dynamic>> apiDeleteComment(int commentId) async {
  final dio = await ApiClient.authed();

  try {
    final res = await dio.post(
      '/delete_comment.php', // ✅ chemin corrigé
      data: FormData.fromMap({'id': commentId}),
    );

    if (res.data['success'] == true || res.data['ok'] == true) {
      return {
        'success': true,
        'message': res.data['message'] ?? 'Commentaire supprimé',
      };
    } else {
      throw Exception(res.data['message'] ?? 'Erreur suppression');
    }
  } on DioException catch (e) {
    print('❌ [apiDeleteComment] ${e.message}');
    throw Exception('Erreur suppression : ${e.message}');
  }
}
