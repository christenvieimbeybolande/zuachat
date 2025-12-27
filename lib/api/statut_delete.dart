import 'dart:convert';
import 'package:dio/dio.dart';
import 'client.dart';

Future<void> apiDeleteStatut(int id) async {
  final dio = await ApiClient.authed();

  final res = await dio.post(
    '/statut_delete.php',
    data: FormData.fromMap({"id": id}),
  );

  final body = res.data;
  if (body['ok'] != true) {
    throw Exception(body['error'] ?? "Erreur inconnue");
  }
}
