import 'package:dio/dio.dart';
import 'client.dart';

Future<List<Map<String, dynamic>>> apiFetchFriendsForChat() async {
  final dio = await ApiClient.authed();

  final Response res = await dio.get('/friends_for_chat.php');
  final body = res.data;

  if (body is! Map || body['ok'] != true) {
    final msg = body is Map && body['error'] != null
        ? body['error'].toString()
        : 'Erreur de chargement des contacts';
    throw Exception(msg);
  }

  final List list = body['data']?['friends'] ?? [];
  return list
      .map<Map<String, dynamic>>(
        (e) => Map<String, dynamic>.from(e as Map),
      )
      .toList();
}
