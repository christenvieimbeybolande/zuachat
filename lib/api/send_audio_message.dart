import 'dart:io';
import 'package:dio/dio.dart';
import 'client.dart';

Future<void> apiSendAudioMessage({
  required int receiverId,
  required String filePath,
  required int duration,
  int? replyTo, // ✅ AJOUT
}) async {
  final dio = await ApiClient.authed();

  final Map<String, dynamic> data = {
    'receiver_id': receiverId,
    'duration': duration,
    'audio': await MultipartFile.fromFile(
      filePath,
      filename: File(filePath).path.split('/').last,
    ),
  };

  // ✅ AJOUT DU reply_to SI EXISTE
  if (replyTo != null) {
    data['reply_to'] = replyTo;
  }

  final formData = FormData.fromMap(data);

  final res = await dio.post(
    '/send_audio_message.php',
    data: formData,
  );

  if (res.data is! Map || res.data['ok'] != true) {
    throw Exception('Erreur envoi audio');
  }
}
