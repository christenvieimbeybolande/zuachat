import 'package:dio/dio.dart';
import 'client.dart';

Future<bool> apiBlockUser(int userId) async {
  final dio = await ApiClient.authed();
  final res = await dio.post(
    '/block_user.php',
    data: {'user_id': userId},
  );
  return res.data['ok'] == true;
}
