import 'dart:io';
import 'package:dio/dio.dart';

import 'client.dart';

/// =======================================================
/// 🎙️ Envoi message audio (compatible ApiClient.authed)
/// =======================================================
Future<void> apiSendAudioMessage({
  required int receiverId,
  required File audioFile,
  required int duration,
}) async {
  final Dio dio = await ApiClient.authed();

  final String fileName = audioFile.path.split('/').last;

  final FormData formData = FormData.fromMap({
    'receiver_id': receiverId.toString(),
    'duration': duration.toString(),
    'audio': await MultipartFile.fromFile(
      audioFile.path,
      filename: fileName,
    ),
  });

  final Response res = await dio.post(
    '/send_audio_message.php',
    data: formData,
    options: Options(
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    ),
  );

  if (res.data is! Map || res.data['ok'] != true) {
    final msg = res.data is Map && res.data['error'] != null
        ? res.data['error'].toString()
        : 'Échec envoi message audio';
    throw Exception(msg);
  }
}
