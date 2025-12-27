import 'package:dio/dio.dart';
import 'client.dart';

Future<Map<String, dynamic>> updateProfile({
  String? nom,
  String? prenom,
  String? postnom,
  String? telephone,
  String? pays,
  String? categorie,
}) async {
  final dio = await ApiClient.authed();

  final Map<String, dynamic> data = {};

  if (nom != null) data['nom'] = nom;
  if (prenom != null) data['prenom'] = prenom;
  if (postnom != null) data['postnom'] = postnom;
  if (telephone != null) data['telephone'] = telephone;
  if (pays != null) data['pays'] = pays;
  if (categorie != null) data['categorie'] = categorie;

  if (data.isEmpty) {
    return {'success': false, 'message': 'Aucune donnée à mettre à jour'};
  }

  try {
    final res = await dio.post(
      '/update_profile.php',
      data: data,
    );

    if (res.statusCode == 200 && res.data is Map) {
      return Map<String, dynamic>.from(res.data);
    }

    return {'success': false, 'message': 'Réponse invalide du serveur'};
  } on DioException catch (e) {
    return {
      'success': false,
      'message': e.response?.data?['message'] ?? e.message,
    };
  }
}
