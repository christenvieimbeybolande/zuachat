import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'client.dart';

Future<Map<String, dynamic>> fetchReels({
  required int page,
  required int limit,
}) async {
  try {
    final dio = await ApiClient.authed();
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString("user_id") ?? "0";

    final res = await dio.get(
      "/fetch_reels.php",
      queryParameters: {
        "page": page,
        "limit": limit,
        "uid": uid,
      },
    );

    print("📹 REELS RESPONSE ===> ${res.data}");

    if (res.statusCode == 200 && res.data is Map) {
      return res.data;
    }

    return {"success": false, "error": "Réponse invalide"};
  } catch (e) {
    print("❌ FETCH REELS ERROR $e");
    return {"success": false, "error": e.toString()};
  }
}
