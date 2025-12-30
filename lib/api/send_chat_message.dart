import 'dart:io';
import 'package:dio/dio.dart';
import 'client.dart';

Future<void> apiSendMessage({
  required int receiverId,
  String? message,
  File? audioFile,
  int? duration,
}) async {
  final dio = await ApiClient.authed();

  final form = FormData.fromMap({
    'receiver_id': receiverId.toString(),
    if (message != null) 'message': message,
    if (duration != null) 'duration': duration.toString(),
    if (audioFile != null)
      'audio': await MultipartFile.fromFile(audioFile.path),
  });

  final res = await dio.post('/send_message_api.php', data: form);

  if (res.data is! Map || res.data['ok'] != true) {
    throw Exception(res.data['error'] ?? 'Échec envoi message');
  }
}
