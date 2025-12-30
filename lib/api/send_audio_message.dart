import 'dart:io';
import 'package:dio/dio.dart';
import 'client.dart';

Future<void> apiSendAudioMessage({
  required int receiverId,
  required String filePath,
  required int duration,
}) async {
  final dio = await ApiClient.authed();

  final formData = FormData.fromMap({
    'receiver_id': receiverId,
    'duration': duration,
    'audio': await MultipartFile.fromFile(
      filePath,
      filename: File(filePath).path.split('/').last,
    ),
  });

  final res = await dio.post(
    '/send_audio_message.php',
    data: formData,
  );

  if (res.data is! Map || res.data['ok'] != true) {
    throw Exception('Erreur envoi audio');
  }
}
