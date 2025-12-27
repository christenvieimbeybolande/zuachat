import 'package:dio/dio.dart';
import 'client.dart';

/// 🔥 Supprime un message
/// forAll = true  → supprimer pour tout le monde
/// forAll = false → supprimer seulement pour moi
Future<Map<String, dynamic>> apiDeleteMessage(int messageId, {required bool forAll}) async {
  final dio = await ApiClient.authed();

  try {
    final res = await dio.post(
      "/delete_message.php",
      data: {
        "message_id": messageId,
        "type": forAll ? "all" : "me",
      },
      options: Options(
        headers: {"Content-Type": "application/json"},
      ),
    );

    if (res.data is Map && res.data["ok"] == true) {
      return {"ok": true};
    }

    return {
      "ok": false,
      "error": res.data["error"] ?? "Échec de la suppression"
    };
  } on DioException catch (e) {
    final message = e.response?.data?["error"] ?? "Erreur réseau";
    return {"ok": false, "error": message};
  } catch (e) {
    return {"ok": false, "error": "Erreur: $e"};
  }
}
