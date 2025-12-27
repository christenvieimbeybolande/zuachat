import 'package:dio/dio.dart';
import 'client.dart';

Future<bool> apiDeleteConversation(int partnerId) async {
  final dio = await ApiClient.authed();

  try {
    final res = await dio.post(
      "/delete_conversation.php",
      data: {"partner_id": partnerId},
    );

    return res.data["ok"] == true;
  } catch (e) {
    print("❌ delete conversation error: $e");
    return false;
  }
}
