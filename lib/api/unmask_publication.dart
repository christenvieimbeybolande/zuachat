import 'package:dio/dio.dart';
import 'client.dart';

Future<Map<String, dynamic>> unmaskPublication(int publicationId) async {
  final dio = await ApiClient.authed();
  try {
    final res = await dio.post('/unmask_publication.php',
        data: {'publication_id': publicationId});
    return Map<String, dynamic>.from(res.data);
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}
