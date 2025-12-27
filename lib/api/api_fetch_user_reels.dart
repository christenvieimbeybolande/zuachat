import 'package:dio/dio.dart';
import 'client.dart';

/// ===========================================================
/// 🌍 API - Reels PUBLICS d’un utilisateur
/// ===========================================================
Future<Map<String, dynamic>> apiFetchUserReels({
  required int userId,
  int page = 1,
  int limit = 10,
}) async {
  try {
    // 🔐 connecté → authed | 🌍 public → raw
    Dio dio;
    try {
      dio = await ApiClient.authed();
    } catch (_) {
      dio = ApiClient.raw();
    }

    final res = await dio.get(
      "/fetch_user_reels.php",
      queryParameters: {
        "user_id": userId,
        "page": page,
        "limit": limit,
      },
    );

    if (res.statusCode == 200 && res.data is Map) {
      final data = Map<String, dynamic>.from(res.data);

      if (data["success"] == true && data["data"] is List) {
        final reels = _normalizeReels(data["data"]);

        return {
          "success": true,
          "data": reels,
          "page": data["page"] ?? page,
          "limit": data["limit"] ?? limit,
          "count": reels.length,
        };
      }

      return {
        "success": false,
        "message": data["message"] ?? "Erreur serveur",
      };
    }

    return {
      "success": false,
      "message": "Réponse invalide (${res.statusCode})",
    };
  } on DioException catch (e) {
    return {
      "success": false,
      "message": e.response?.data?["message"] ?? e.message,
    };
  } catch (e) {
    return {
      "success": false,
      "message": "Erreur interne : $e",
    };
  }
}

/// ===========================================================
/// 🔧 Normalisation (IDENTIQUE à MyReels)
/// ===========================================================
List<Map<String, dynamic>> _normalizeReels(dynamic raw) {
  if (raw is! List) return [];

  return raw.map<Map<String, dynamic>>((r) {
    final item = Map<String, dynamic>.from(r);

    item["id"] = int.tryParse("${item["id"]}") ?? 0;
    item["thumbnail"] = (item["thumbnail"] ?? "").toString();
    item["video"] = (item["video"] ?? "").toString();
    item["texte"] = (item["texte"] ?? "").toString();
    item["created_at"] = (item["created_at"] ?? "").toString();

    item["likes"] = int.tryParse("${item["likes"] ?? 0}") ?? 0;
    item["comments"] = int.tryParse("${item["comments"] ?? 0}") ?? 0;
    item["views"] = int.tryParse("${item["views"] ?? 0}") ?? 0;

    item["liked"] = item["liked"] == true;
    item["my_emoji"] = item["my_emoji"];

    if (item["auteur"] is Map) {
      item["auteur"] = Map<String, dynamic>.from(item["auteur"]);
    } else {
      item["auteur"] = {
        "id": 0,
        "username": "",
        "nom": "Utilisateur",
        "photo": "",
        "badge_verified": 0,
      };
    }

    return item;
  }).toList();
}
