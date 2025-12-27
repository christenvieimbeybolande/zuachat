import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'client.dart';

typedef ProgressCallback = void Function(int sentBytes, int totalBytes);

Future<void> apiAddPublication({
  required String texte,
  required String visibility,
  String? backgroundColorHex, // ex: #FF0000 or '' if none
  List<File>? fichiers,
  required String typePublication, // 'normal' | 'reel' | 'text'
  ProgressCallback? onSendProgress,
}) async {
  final dio = await ApiClient.authed();

  final formData = FormData();

  formData.fields
    ..add(MapEntry('texte', texte))
    ..add(MapEntry('visibility', visibility))
    ..add(MapEntry('type_publication', typePublication))
    ..add(MapEntry('background_color', backgroundColorHex ?? ''));

  if (fichiers != null && fichiers.isNotEmpty) {
    for (final file in fichiers) {
      final fileName = file.path.split('/').last;
      formData.files.add(MapEntry(
        'fichiers[]',
        await MultipartFile.fromFile(file.path, filename: fileName),
      ));
    }
  }

  try {
    final response = await dio.post(
      '/add_publication.php',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
      onSendProgress: (sent, total) {
        if (onSendProgress != null) onSendProgress(sent, total);
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur serveur (${response.statusCode})');
    }

    final data = response.data;
    if (data is! Map || data['success'] != true) {
      final message = data['message'] ?? 'Erreur inconnue';
      throw Exception(message);
    }
  } on DioException catch (e) {
    // ⏳ Upload long ≠ échec
    if (e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw Exception(
        "Upload en cours… La publication sera visible dans quelques instants.",
      );
    }

    final resp = e.response;
    if (resp != null && resp.data is Map && resp.data['message'] != null) {
      throw Exception(resp.data['message']);
    }

    throw Exception("Erreur réseau");
  }
}
