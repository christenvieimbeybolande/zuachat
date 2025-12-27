import 'package:dio/dio.dart';
import 'client.dart';

Future<Map<String, dynamic>> fetchDashboard() async {
  final dio = await ApiClient.authed();

  final Response res = await dio.get('/dashboard.php');

  if (res.data is! Map || res.data['success'] != true) {
    throw Exception(res.data['error'] ?? 'Erreur chargement dashboard');
  }

  return Map<String, dynamic>.from(res.data['data']);
}
