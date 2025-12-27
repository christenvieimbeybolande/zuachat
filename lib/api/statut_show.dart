import 'package:dio/dio.dart';
import 'client.dart';

/// 🔹 Récupère le détail d’un statut + tous les statuts de l’utilisateur
///
/// Retourne un Map propre :
/// {
///   "statut": {...},
///   "medias": [...],
///   "all_statuts": [...]
/// }
Future<Map<String, dynamic>> apiStatutShow(int id) async {
  final dio = await ApiClient.authed();

  try {
    final res = await dio.get(
      '/statut_show.php',
      queryParameters: {'id': id},
    );

    if (res.statusCode != 200 || res.data is! Map) {
      throw Exception('Réponse inattendue du serveur (statut show)');
    }

    final body = res.data as Map;

    if (body['ok'] != true) {
      final err = (body['error'] ?? {}) as Map?;
      final msg = (err?['message'] ?? 'Erreur chargement statut').toString();
      throw Exception(msg);
    }

    final rawData = body['data'];

    if (rawData is! Map) {
      throw Exception("Format data invalide (data n'est pas un objet)");
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(rawData);

    // ------------------------------------------------------------------
    // 1️⃣ Sécuriser "statut"
    // ------------------------------------------------------------------
    data['statut'] = (data['statut'] is Map)
        ? Map<String, dynamic>.from(data['statut'])
        : <String, dynamic>{};

    // ------------------------------------------------------------------
    // 2️⃣ Sécuriser "medias"
    // ------------------------------------------------------------------
    if (data['medias'] is List) {
      data['medias'] = (data['medias'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else {
      data['medias'] = <Map<String, dynamic>>[];
    }

    // ------------------------------------------------------------------
    // 3️⃣ Sécuriser "all_statuts"
    // ------------------------------------------------------------------
    if (data['all_statuts'] is List) {
      data['all_statuts'] = (data['all_statuts'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else {
      data['all_statuts'] = <Map<String, dynamic>>[];
    }

    return data;
  } on DioException catch (e) {
    final msg = e.response?.data is Map
        ? (((e.response!.data as Map)['error']?['message'])?.toString() ??
            'Erreur réseau (${e.response?.statusCode})')
        : 'Erreur réseau (${e.response?.statusCode})';
    throw Exception(msg);
  } catch (e) {
    throw Exception(
      e.toString().replaceFirst('Exception:', '').trim(),
    );
  }
}
