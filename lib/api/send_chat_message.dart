import 'dart:convert';
import 'package:dio/dio.dart';
import 'client.dart';

Future<void> apiSendChatMessage({
  required int receiverId,
  required String message,
}) async {
  final dio = await ApiClient.authed();

  final Response res = await dio.post(
    '/send_message_api.php',
    data: jsonEncode({
      'receiver_id': receiverId,
      'message': message,
    }),
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
