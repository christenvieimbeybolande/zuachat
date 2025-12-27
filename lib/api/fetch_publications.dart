import 'package:dio/dio.dart';
import 'client.dart';

/// ===========================================================
/// 📢 API - Récupération des publications d’un profil (Pagination)
/// ===========================================================

Future<Map<String, dynamic>> fetchPublications({
  int? userId,
  int page = 1,
  int limit = 10,
}) async {
  try {
    final dio = await ApiClient.authed();

    final res = await dio.get(
      "/fetch_publications.php",
      queryParameters: {
        if (userId != null) "user_id": userId,
        "page": page,
        "limit": limit,
      },
    );

    if (res.statusCode == 200 && res.data is Map) {
      final data = res.data as Map<String, dynamic>;

      if (data["success"] == true && data["data"] is List) {
        final list = _normalizePublications(data["data"]);

        return {
          "success": true,
          "data": list,
          "page": data["page"] ?? page,
          "limit": data["limit"] ?? limit,
          "count": data["count"] ?? list.length,
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
    return {"success": false, "message": "Erreur interne : $e"};
  }
}

/// ===========================================================
/// 🔧 Nettoyage des publications
/// ===========================================================

List<Map<String, dynamic>> _normalizePublications(dynamic rawList) {
  if (rawList is! List) return [];

  return rawList.map<Map<String, dynamic>>((pub) {
    final p = Map<String, dynamic>.from(pub);

    // Fichiers
    if (p["fichiers"] is! List) p["fichiers"] = [];

    // Réactions
    if (p["reactions"] is List) {
      p["reactions"] = (p["reactions"] as List)
          .whereType<Map>()
          .map((r) => {
                "emoji": r["emoji"] ?? "",
                "c": int.tryParse("${r["c"] ?? 0}") ?? 0,
              })
          .toList();
    } else {
      p["reactions"] = [];
    }

    p["liked"] = (p["liked"] == true || p["liked"] == 1);
    p["is_liked"] = p["liked"];
    p["my_emoji"] = p["my_emoji"]?.toString() ?? "";

    return p;
  }).toList();
}
