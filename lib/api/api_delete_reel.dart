import 'package:dio/dio.dart';
import 'client.dart';

/// 🔥 Supprimer un reel par ID
Future<Map<String, dynamic>> apiDeleteReel(int reelId) async {
  try {
    final dio = await ApiClient.authed();

    final res = await dio.post(
      "/delete_reel.php",
      data: {
        "reel_id": reelId, // ✅ EXACTEMENT ce que PHP attend
      },
    );

    if (res.statusCode == 200 && res.data is Map) {
      final data = res.data as Map<String, dynamic>;

      return {
        "success": data["success"] == true,
        "message": data["message"] ?? "OK",
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
