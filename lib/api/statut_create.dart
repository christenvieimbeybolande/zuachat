import 'dart:convert';
import 'package:dio/dio.dart';
import 'client.dart';

/// 💬 Création d’un statut (story)
/// `mediaPath` = chemin relatif renvoyé par upload_statut_media.php
Future<int> apiStatutCreate(
  String mediaPath, {
  String visibility = 'public',
  String caption = '',
}) async {
  final dio = await ApiClient.authed();

  try {
    final res = await dio.post(
      '/statut_create.php',
      data: jsonEncode({
        'media': mediaPath,
        'visibility': visibility,
        'caption': caption,
      }),
    );

    if (res.statusCode != 200 || res.data is! Map) {
      throw Exception('Réponse inattendue du serveur (création statut)');
    }

    final body = res.data as Map;

    if (body['ok'] != true) {
      final err = (body['error'] ?? {}) as Map?;
      final msg = (err?['message'] ?? 'Erreur envoi statut').toString();
      throw Exception(msg);
    }

    final data = body['data'] as Map? ?? {};
    final id = data['id'];

    if (id is! int) {
      throw Exception('ID statut manquant dans la réponse');
    }

    return id;
  } on DioException catch (e) {
    final msg = e.response?.data is Map
        ? (((e.response!.data as Map)['error']?['message'])?.toString() ??
            'Erreur réseau (${e.response?.statusCode})')
        : 'Erreur réseau (${e.response?.statusCode})';
    throw Exception(msg);
  } catch (e) {
    throw Exception(e.toString().replaceFirst('Exception: ', ''));
  }
}
