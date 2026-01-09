import 'client.dart';

Future<bool> apiUnblockUser(int userId) async {
  final dio = await ApiClient.authed();
  final res = await dio.post(
    '/unblock_user.php',
    data: {'user_id': userId},
  );
  return res.data['ok'] == true;
}
