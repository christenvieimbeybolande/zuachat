import 'package:dio/dio.dart';
import 'client.dart';

Future<Map<String, dynamic>> apiGetPublicationReactions(
    int publicationId) async {
  final dio = await ApiClient.authed();

  try {
    final res = await dio.get(
      "/get_publication_reactions.php",
      queryParameters: {"id": publicationId},
    );

    if (res.statusCode == 200 && res.data is Map) {
      final body = res.data as Map;

      return {
        "success": body["success"] ?? true,
        "users": body["users"] ?? [],
        "count": body["count"] ?? 0,
        "summary": body["summary"] ?? {}, // 🔥 AJOUT IMPORTANT
      };
    }
  } catch (e) {
    return {
      "success": false,
      "message": e.toString(),
    };
  }

  return {"success": false, "message": "Réponse invalide"};
}
