import 'package:dio/dio.dart';
import 'client.dart';

Future<Map<String, dynamic>?> fetchSinglePublication(int publicationId) async {
  try {
    final dio = await ApiClient.authed();

    final res = await dio.get(
      '/fetch_publication_single.php',
      queryParameters: {'id': publicationId},
    );

    if (res.statusCode == 200 && res.data['success'] == true) {
      return Map<String, dynamic>.from(res.data['data']);
    }
  } on DioException catch (e) {
    print("❌ fetchSinglePublication: ${e.message}");
  } catch (e) {
    print("❌ fetchSinglePublication: $e");
  }

  return null;
}
