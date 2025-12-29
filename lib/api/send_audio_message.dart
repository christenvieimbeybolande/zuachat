import 'dart:io';
import 'package:dio/dio.dart';
import 'client.dart';

Future<void> apiSendAudioMessage({
  required int receiverId,
  required File audioFile,
  required int duration,
}) async {
  final dio = await ApiClient.authed();

  final form = FormData.fromMap({
    "receiver_id": receiverId,
    "duration": duration,
    "audio": await MultipartFile.fromFile(
      audioFile.path,
      filename: audioFile.path.split('/').last,
    ),
  });

  final res = await dio.post(
    "/send_audio_message.php",
    data: form,
  );

  if (res.data is! Map || res.data["ok"] != true) {
    throw Exception("Erreur envoi audio");
  }
}
