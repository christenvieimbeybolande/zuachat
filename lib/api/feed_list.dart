import 'package:dio/dio.dart';
import 'client.dart';

/// 📡 Récupère la liste des publications du fil d'actualité
/// Retourne une `List<Map<String, dynamic>>`
///
/// Exemple format JSON attendu :
/// {
///   "ok": true,
///   "data": {
///     "feed": [
///       { "id": 1, "texte": "Salut", "fichiers": [], ... },
///       { "id": 2, "texte": "Photo de profil changée", ... }
///     ]
///   }
/// }
Future<List<Map<String, dynamic>>> apiFeedList() async {
  final dio = await ApiClient.authed();

  try {
    final res = await dio.get('/feed_list.php');
    final body = res.data;

    // ⚠️ Vérification de succès côté API
    if (body['ok'] != true) {
      final msg = body['error']?['message'] ?? body['error'] ?? 'Erreur feed';
      throw Exception(msg);
    }

    final data = body['data'];
    if (data == null || data['feed'] == null) {
      throw Exception('Aucune donnée disponible dans le flux.');
    }

    final List feed = data['feed'];
    return feed.map((e) => Map<String, dynamic>.from(e)).toList();
  } on DioException catch (e) {
    // Gestion propre des erreurs réseau
    final msg = e.response?.data?['error'] ??
        'Erreur réseau (${e.response?.statusCode ?? 'inconnue'})';
    throw Exception(msg);
  } catch (e) {
    throw Exception('Erreur: $e');
  }
}
