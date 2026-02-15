import 'dart:io';
import 'package:dio/dio.dart';
import 'client.dart';

/// Types autorisés côté serveur
/// image | video | document | contact
Future<void> apiSendFileMessage({
  required int receiverId,
  required String type,
  
  File? file, // image | video | document
  Map<String, dynamic>? contactData, // contact (JSON)

  String? message,
  int? replyTo,
}) async {
  final dio = await ApiClient.authed();

  // 🔒 sécurité côté client (double protection)
  const allowedTypes = ['image', 'video', 'document', 'contact'];
  if (!allowedTypes.contains(type)) {
    throw Exception("Type de fichier non autorisé");
  }

  final formData = FormData();

  // =====================================================
  // 📥 CHAMPS COMMUNS
  // =====================================================
  formData.fields
    ..add(MapEntry('receiver_id', receiverId.toString()))
    ..add(MapEntry('type', type));

  if (message != null && message.trim().isNotEmpty) {
    formData.fields.add(MapEntry('message', message.trim()));
  }

  if (replyTo != null) {
    formData.fields.add(MapEntry('reply_to', replyTo.toString()));
  }

  // =====================================================
  // 👤 CONTACT (PAS DE FICHIER)
  // =====================================================
  if (type == 'contact') {
    if (contactData == null) {
      throw Exception("contactData requis pour type contact");
    }

    formData.fields.add(
      MapEntry('contact_data', contactData.toString()),
    );
  }

  // =====================================================
  // 📎 FICHIER (IMAGE / VIDEO / DOCUMENT)
  // =====================================================
  if (type != 'contact') {
    if (file == null) {
      throw Exception("Fichier requis pour le type $type");
    }

    final fileName = file.path.split('/').last;

    formData.files.add(
      MapEntry(
        'file',
        await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      ),
    );
  }

  // =====================================================
  // 🚀 ENVOI
  // =====================================================
  final res = await dio.post(
    '/send_message_with_file.php',
    data: formData,
    options: Options(contentType: 'multipart/form-data'),
  );

  final data = res.data;

  if (data is! Map || data['ok'] != true) {
    final msg = data is Map && data['error'] != null
        ? data['error'].toString()
        : "Erreur lors de l'envoi du fichier";
    throw Exception(msg);
  }
}
