import 'dart:convert';
import 'package:dio/dio.dart';
import 'client.dart';

Future<Map<String, dynamic>> apiFeedCreate(String contenu,
    {String? media}) async {
  final dio = await ApiClient.authed();
  final res = await dio.post('/feed_create.php',
      data: jsonEncode({'contenu': contenu, 'media': media ?? ''}));
  final body = res.data;
  if (body['ok'] != true) {
    throw Exception(body['error']?['message'] ?? 'Erreur création');
  }
  return Map<String, dynamic>.from(body['data']['post']);
}
