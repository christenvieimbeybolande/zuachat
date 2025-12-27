import 'package:dio/dio.dart';
import 'client.dart';

/// ===========================================================
/// 👥 API - LISTE DES ABONNÉS (followers)
/// ===========================================================

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == '1' || v.toLowerCase() == 'true';
  return false;
}

Future<Map<String, dynamic>> fetchFollowers(int userId) async {
  final dio = await ApiClient.authed();

  try {
    print("📡 [FOLLOWERS] ➝ /followers_list.php?user_id=$userId");

    final res = await dio.get(
      '/followers_list.php',
      queryParameters: {'user_id': userId},
    );

    if (res.statusCode == 200 && res.data['success'] == true) {
      final list = List<Map<String, dynamic>>.from(res.data['followers'] ?? []);

      // 🔥 Conversion propre des booléens
      for (var u in list) {
        u['is_following'] = _asBool(u['is_following']);
        u['is_followed_by_me'] = _asBool(u['is_followed_by_me']);
      }

      return {
        "ok": true,
        "followers": list,
      };
    }

    return {"ok": false, "message": "Réponse invalide"};
  } on DioException catch (e) {
    return {"ok": false, "message": "Erreur réseau: ${e.message}"};
  } catch (e) {
    return {"ok": false, "message": e.toString()};
  }
}
