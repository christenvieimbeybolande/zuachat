import 'client.dart';
import 'package:dio/dio.dart';

Future<List<Map<String, dynamic>>> apiStatutAll(int page) async {
  final dio = await ApiClient.authed();

  final res = await dio.get(
    "/statut_all.php",
    queryParameters: {"page": page},
  );

  if (res.statusCode != 200 || res.data is! Map) {
    throw Exception("Réponse API invalide");
  }

  final body = res.data;

  if (body["ok"] != true) {
    throw Exception("Erreur API statuts");
  }

  final rows = body["data"]["statuts"];
  if (rows is! List) return [];

  return rows.map((e) => Map<String, dynamic>.from(e)).toList();
}
