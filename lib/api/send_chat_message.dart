import 'dart:convert';
import 'package:dio/dio.dart';
import 'client.dart';

Future<void> apiSendChatMessage({
  required int receiverId,
  required String message,
  String type = 'text', // ✅ AJOUT
  int? replyTo, // ✅ NOUVEAU (réponse à un message)
}) async {
  final dio = await ApiClient.authed();

  final Map<String, dynamic> payload = {
    'receiver_id': receiverId,
    'message': message,
  };

  // 🔥 AJOUT reply_to seulement si présent
  if (replyTo != null) {
    payload['reply_to'] = replyTo;
  }

  final Response res = await dio.post(
    '/send_message_api.php',
    data: jsonEncode(payload),
    options: Options(
      headers: {'Content-Type': 'application/json'},
    ),
  );

  final body = res.data;
  if (body is! Map || body['ok'] != true) {
    final msg = body is Map && body['error'] != null
        ? body['error'].toString()
        : "Erreur lors de l'envoi";
    throw Exception(msg);
  }
}
