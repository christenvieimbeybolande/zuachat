import 'package:dio/dio.dart';
import 'client.dart';

/// 🔹 Liste des viewers d’un statut (pour le propriétaire)
///
/// Retourne une LISTE de users :
/// [
///   { id, prenom, nom, postnom, photo, badge_verified },
///   ...
/// ]
Future<List<Map<String, dynamic>>> apiStatutViewers(int statutId) async {
  final dio = await ApiClient.authed();

  try {
    final res = await dio.get(
      '/statut_viewers.php',
      queryParameters: {'id': statutId},
    );

    if (res.statusCode != 200 || res.data is! Map) {
      throw Exception('Réponse inattendue du serveur (liste vues statut)');
    }

    final Map body = res.data as Map;

    if (body['ok'] != true) {
      final err = body['error'] as Map?;
      final msg =
          (err?['message'] ?? 'Erreur chargement vues du statut').toString();
      throw Exception(msg);
    }

    final data = body['data'];
    if (data == null || data is! Map) {
      throw Exception('Format data invalide (pas un objet)');
    }

    final raw = data['viewers'];
    if (raw == null) return [];

    if (raw is! List) {
      throw Exception('Format de la liste des vues invalide');
    }

    return raw.map<Map<String, dynamic>>((e) {
      if (e is Map) {
        return Map<String, dynamic>.from(e);
      }
      return <String, dynamic>{};
    }).toList(growable: false);
  } on DioException catch (e) {
    final status = e.response?.statusCode;
    final msg = e.response?.data is Map
        ? (((e.response!.data as Map)['error']?['message'])?.toString() ??
            'Erreur réseau ($status)')
        : 'Erreur réseau ($status)';
    throw Exception(msg);
  } catch (e) {
    throw Exception(e.toString().replaceFirst('Exception: ', ''));
  }
}
