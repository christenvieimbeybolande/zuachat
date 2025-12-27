import 'dart:io';
import 'package:dio/dio.dart';
import 'client.dart';

/// 📤 Upload d’un média de statut
/// Retourne le chemin relatif à stocker en BDD (ex: "uploads/statuts/xxx.jpg")
Future<String> uploadStatutMedia(File file) async {
  final dio = await ApiClient.authed();

  final fileName = file.path.split('/').last;

  try {
    final formData = FormData.fromMap({
      'media': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
    });

    final res = await dio.post(
      '/upload_statut_media.php',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    if (res.statusCode != 200 || res.data is! Map) {
      throw Exception('Réponse inattendue du serveur (upload statut)');
    }

    final body = res.data as Map;

    if (body['ok'] != true) {
      final err = (body['error'] ?? {}) as Map?;
      final msg = (err?['message'] ?? 'Erreur upload média statut').toString();
      throw Exception(msg);
    }

    final data = body['data'] as Map?;
    final path = data?['path'] as String?;

    if (path == null || path.isEmpty) {
      throw Exception('Chemin du média manquant dans la réponse');
    }

    return path;
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
