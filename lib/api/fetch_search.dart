import 'package:dio/dio.dart';
import 'client.dart';

/// 🔍 Recherche profils + publications
///
/// Retourne toujours une Map:
/// {
///   "success": true/false,
///   "data": {
///      "profils": [...],
///      "publications": [...],
///   },
///   "message": "...",
/// }
Future<Map<String, dynamic>> fetchSearch(String q) async {
  if (q.trim().isEmpty) {
    return {
      "success": false,
      "message": "Requête vide",
      "data": {"profils": [], "publications": []}
    };
  }

  final dio = await ApiClient.authed();

  try {
    print("📡 [SEARCH] ➝ GET /search.php?q=$q");

    final Response res = await dio.get(
      "/search.php",
      queryParameters: {"q": q},
    );

    // Vérifie code HTTP
    if (res.statusCode != 200) {
      return {
        "success": false,
        "message": "Code HTTP inattendu ${res.statusCode}",
        "data": {"profils": [], "publications": []}
      };
    }

    // Vérifie format JSON
    if (res.data is! Map) {
      return {
        "success": false,
        "message": "Format de réponse invalide",
        "data": {"profils": [], "publications": []}
      };
    }

    final Map<String, dynamic> json = Map<String, dynamic>.from(res.data);

    // -----------------------------
    // EXTRACTION (CORRECTE) DE data
    // -----------------------------
    final data = json["data"] is Map
        ? Map<String, dynamic>.from(json["data"])
        : {"profils": [], "publications": []};

    final profils = List<Map<String, dynamic>>.from(data["profils"] ?? []);
    final publications =
        List<Map<String, dynamic>>.from(data["publications"] ?? []);

    print("✅ [SEARCH] Profils trouvés: ${profils.length}");
    print("✅ [SEARCH] Publications trouvées: ${publications.length}");

    return {
      "success": json["success"] == true,
      "message": json["message"] ?? "",
      "data": {
        "profils": profils,
        "publications": publications,
      }
    };
  } on DioException catch (e) {
    print("❌ [SEARCH] DioException: ${e.message}");
    return {
      "success": false,
      "message": "Erreur réseau",
      "data": {"profils": [], "publications": []}
    };
  } catch (e) {
    print("❌ [SEARCH] Exception: $e");
    return {
      "success": false,
      "message": e.toString(),
      "data": {"profils": [], "publications": []}
    };
  }
}
