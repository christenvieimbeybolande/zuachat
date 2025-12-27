// lib/api/api_add_reel_view.dart
import 'package:dio/dio.dart';
import 'client.dart';

/// ===========================================================
/// 👁️ Ajout d’une vue sur un reel
/// (1 vue / utilisateur / reel)
/// ===========================================================
Future<void> apiAddReelView(int reelId) async {
  try {
    final dio = await ApiClient.authed();

    final res = await dio.post(
      "/add_reel_view.php",
      data: {
        "reel_id": reelId,
      },
    );

    if (res.statusCode == 200 && res.data is Map) {
      if (res.data["success"] != true) {
        throw Exception(res.data["message"] ?? "Vue non enregistrée");
      }
    }
  } on DioException catch (e) {
    print("❌ ADD REEL VIEW ERROR ${e.response?.data}");
    rethrow;
  } catch (e) {
    print("❌ ADD REEL VIEW ERROR $e");
    rethrow;
  }
}
