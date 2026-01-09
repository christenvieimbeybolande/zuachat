import 'client.dart';

Future<bool> apiIsBlocked(int userId) async {
  final dio = await ApiClient.authed();
  final res = await dio.get(
    '/is_blocked.php',
    queryParameters: {'user_id': userId},
  );
  return res.data['blocked'] == true;
}
