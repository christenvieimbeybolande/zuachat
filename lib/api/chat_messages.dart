import 'package:dio/dio.dart';
import 'client.dart';

Future<List<Map<String, dynamic>>> apiFetchChatMessages(int contactId) async {
  final dio = await ApiClient.authed();

  final Response res = await dio.get(
    '/chat_messages.php',
    queryParameters: {'contact_id': contactId},
  );

  final body = res.data;

  if (body is! Map || body['ok'] != true) {
    final msg = body is Map && body['error'] != null
        ? body['error'].toString()
        : 'Erreur de chargement des messages';
    throw Exception(msg);
  }

  final List list = body['data']?['messages'] ?? [];
  return list
      .map<Map<String, dynamic>>(
        (e) => Map<String, dynamic>.from(e as Map),
      )
      .toList();
}
