import 'package:dio/dio.dart';
import 'client.dart';

/// ===========================================================
/// 🔔 API - Récupération des notifications ZuaChat
/// ===========================================================
/// Retourne :
/// {
///   success: true/false,
///   data: {
///     unread_messages: 0,
///     unread_notifications: 3,
///     notifications: [
///       {
///         id, type, publication_id, comment_id, seen,
///         created_at, time_ago,
///         sender: { id, fullname, photo, badge_verified }
///       }
///     ]
///   }
/// }
/// ===========================================================
Future<Map<String, dynamic>> fetchNotifications() async {
  try {
    final dio = await ApiClient.authed();

    print('📡 [NOTIFS] ➝ Appel API /notifications.php...');
    final res = await dio.get('/notifications.php');

    print('✅ [NOTIFS] Réponse ${res.statusCode}: ${res.data}');
    if (res.statusCode == 200 && res.data is Map) {
      final data = res.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return {
          'success': true,
          'data': data['data'] ?? {},
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur serveur inconnue',
        };
      }
    } else {
      return {
        'success': false,
        'message': 'Réponse invalide du serveur (${res.statusCode})',
      };
    }
  } on DioException catch (e) {
    print('❌ [NOTIFS] Erreur Dio: ${e.message}');
    return {
      'success': false,
      'message': e.response?.data?['message'] ??
          'Erreur réseau : ${e.message ?? 'Inconnue'}',
    };
  } catch (e) {
    print('❌ [NOTIFS] Exception: $e');
    return {'success': false, 'message': 'Erreur interne : $e'};
  }
}
