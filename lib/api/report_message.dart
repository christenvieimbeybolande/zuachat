import 'package:dio/dio.dart';
import 'client.dart';

Future<bool> apiReportMessage({
  required int messageId,
  required String reason,
}) async {
  final dio = await ApiClient.authed();
  final res = await dio.post(
    '/report_message.php',
    data: {
      'message_id': messageId,
      'reason': reason,
    },
  );
  return res.data['ok'] == true;
}
