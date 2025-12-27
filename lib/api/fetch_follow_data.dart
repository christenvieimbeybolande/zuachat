import 'package:dio/dio.dart';
import 'client.dart';

/// 📡 Récupère la liste des abonnés OU abonnements selon mode:
/// mode = "followers" → ceux qui te suivent
/// mode = "following" → ceux que tu suis
Future<Map<String, dynamic>> fetchFollowData(String mode) async {
  final dio = await ApiClient.authed();

  try {
    final res = await dio.get(
      "/fetch_follow_data.php",
      queryParameters: {"mode": mode},
    );

    if (res.statusCode == 200 && res.data is Map) {
      return res.data;
    }

    return {"success": false, "message": "Réponse invalide"};
  } catch (e) {
    return {"success": false, "message": e.toString()};
  }
}
