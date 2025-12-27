import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'client.dart';

Future<void> apiLogout() async {
  final prefs = await SharedPreferences.getInstance();

  try {
    final dio = await ApiClient.authed();
    final sessionId = prefs.getString('current_session_id');

    await dio.post('/delete_session.php', data: {
      'session_id': sessionId,
    });
  } catch (e) {
    print("⚠️ Erreur logout API ignorée : $e");
  } finally {
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('current_session_id');
    await prefs.remove('device_type');
    await prefs.remove('last_ip');

    await ApiClient.reset(); // 🔥 ESSENTIEL

    print("🧹 Déconnexion locale effectuée");
  }
}
