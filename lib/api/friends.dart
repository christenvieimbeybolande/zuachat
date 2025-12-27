import 'package:dio/dio.dart';
import 'client.dart';

/// ===========================================================
/// 👥 API - FRIENDS (Liste d’amis / abonnements ZuaChat)
/// ===========================================================
/// Récupère :
/// - invitations reçues
/// - tous les membres du réseau
/// avec leur statut (suivi / non suivi)
/// ===========================================================
Future<Map<String, dynamic>> fetchFriendsData() async {
  final dio = await ApiClient.authed();

  try {
    print('📡 [FRIENDS] ➝ Appel API /friends.php...');
    final res = await dio.get('/friends.php');

    if (res.statusCode == 200 && res.data is Map && res.data['ok'] == true) {
      final data = Map<String, dynamic>.from(res.data['data'] ?? {});

      final invitations = List<Map<String, dynamic>>.from(
        (data['invitations'] ?? []).whereType<Map>().toList(),
      );

      final users = List<Map<String, dynamic>>.from(
        (data['users'] ?? []).whereType<Map>().toList(),
      );

      print(
          "✅ [FRIENDS] Invitations: ${invitations.length}, Membres: ${users.length}");

      return {
        "ok": true,
        "invitations": invitations,
        "users": users,
      };
    } else {
      print('⚠️ [FRIENDS] Réponse invalide: ${res.data}');
      return {"ok": false, "message": "Réponse vide ou invalide"};
    }
  } on DioException catch (e) {
    print('❌ [FRIENDS] Erreur Dio: ${e.message}');
    return {"ok": false, "message": "Erreur réseau: ${e.message}"};
  } catch (e, st) {
    print('💥 [FRIENDS] Exception: $e');
    print(st);
    return {"ok": false, "message": e.toString()};
  }
}
