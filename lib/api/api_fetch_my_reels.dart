import 'package:dio/dio.dart';
import 'client.dart';

/// ===========================================================
/// 📢 API - Récupération des reels de l’utilisateur connecté
/// ===========================================================
Future<Map<String, dynamic>> apiFetchMyReels({
  int page = 1,
  int limit = 10,
}) async {
  try {
    final dio = await ApiClient.authed();

    final res = await dio.get(
      "/fetch_my_reels.php",
      queryParameters: {
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
      "message": "Réponse invalide du serveur (${res.statusCode})",
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
/// 🔧 Normalisation complète des reels (SAFE POUR UI)
/// ===========================================================
List<Map<String, dynamic>> _normalizeReels(dynamic raw) {
  if (raw is! List) return [];

  return raw.map<Map<String, dynamic>>((r) {
    final item = Map<String, dynamic>.from(r);

    // =========================
    // ID
    // =========================
    item["id"] = int.tryParse("${item["id"]}") ?? 0;

    // =========================
    // Contenu texte / media
    // =========================
    item["thumbnail"] = (item["thumbnail"] ?? "").toString();
    item["video"] = (item["video"] ?? "").toString();
    item["texte"] = (item["texte"] ?? "").toString();
    item["created_at"] = (item["created_at"] ?? "").toString();

    // =========================
    // Stats (obligatoires pour UI)
    // =========================
    item["likes"] = int.tryParse("${item["likes"] ?? 0}") ?? 0;
    item["comments"] = int.tryParse("${item["comments"] ?? 0}") ?? 0;
    item["views"] = int.tryParse("${item["views"] ?? 0}") ?? 0;

    // =========================
    // Like utilisateur
    // =========================
    item["liked"] = item["liked"] == true;
    item["my_emoji"] = item["my_emoji"];

    // =========================
    // Auteur (sécurisé)
    // =========================
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
