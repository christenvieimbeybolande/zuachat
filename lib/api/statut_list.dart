import 'package:dio/dio.dart';
import 'client.dart';

/// =============================================================
/// 🔵 API STATUTS — PAGINATION (page, limit)
/// =============================================================
/// Retourne :
/// [
///   {
///     "user": {...},
///     "statuts": [
///         { id, created_at, media_preview }
///     ]
///   },
///   ...
/// ]
/// =============================================================
Future<List<Map<String, dynamic>>> apiStatutList({
  int page = 1,
  int limit = 10,
}) async {
  final dio = await ApiClient.authed();

  final res = await dio.get(
    '/statut_list.php',
    queryParameters: {
      'page': page,
      'limit': limit,
    },
  );

  // ---- Vérification réponse ----
  if (res.statusCode != 200 || res.data is! Map) {
    throw Exception("Réponse inattendue du serveur (statuts)");
  }

  final Map<String, dynamic> body = Map<String, dynamic>.from(res.data);

  if (body['ok'] != true) {
    final err = body['error'];
    final msg = (err is Map ? err['message'] : err)?.toString() ??
        "Erreur chargement statuts";
    throw Exception(msg);
  }

  // ---- Validation structure ----
  final data = body['data'];
  if (data == null || data is! Map) {
    throw Exception("Données statuts invalides (data manquant)");
  }

  final raw = data['statuts'];

  if (raw == null) return [];
  if (raw is! List) {
    throw Exception("Format statuts incorrect (doit être une liste)");
  }

  // ---- Conversion propre ----
  return raw.map<Map<String, dynamic>>((e) {
    if (e is Map<String, dynamic>) {
      return Map<String, dynamic>.from(e);
    }
    return <String, dynamic>{};
  }).toList();
}
