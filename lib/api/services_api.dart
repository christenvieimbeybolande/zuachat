import 'client.dart';

class ServicesApi {
  static Future<List<Map<String, dynamic>>> fetchServices() async {
    final dio = await ApiClient.authed();
    final res = await dio.get('/services/services.php');
    return List<Map<String, dynamic>>.from(res.data['services'] ?? []);
  }

  static Future<void> activate(String service) async {
    final dio = await ApiClient.authed();
    await dio.post('/services/activate.php', data: {
      'service_code': service,
    });
  }

  static Future<void> deactivate(String service) async {
    final dio = await ApiClient.authed();
    await dio.post('/services/deactivate.php', data: {
      'service_code': service,
    });
  }

  static Future<void> reset(String service) async {
    final dio = await ApiClient.authed();
    await dio.post('/services/reset.php', data: {
      'service_code': service,
    });
  }
}
