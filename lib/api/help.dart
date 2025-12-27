import 'package:dio/dio.dart';
import 'client.dart';

/// 🔹 Récupère le ticket actif et ses messages
Future<Map<String, dynamic>> fetchHelpTicket() async {
  final dio = await ApiClient.authed();
  try {
    final res = await dio.get('/help_fetch_ticket.php');
    if (res.statusCode == 200 && res.data is Map) {
      return res.data;
    }
    return {'success': false, 'message': 'Réponse invalide'};
  } on DioException catch (e) {
    return {'success': false, 'message': e.message};
  }
}

/// ✉️ Envoie un message dans un ticket actif
Future<Map<String, dynamic>> sendHelpMessage(
    int ticketId, String message) async {
  final dio = await ApiClient.authed();
  try {
    final res = await dio.post('/help_send_message.php', data: {
      'ticket_id': ticketId,
      'message': message,
    });
    return res.data;
  } on DioException catch (e) {
    return {'success': false, 'message': e.message};
  }
}

/// 🆕 Crée un nouveau ticket d’assistance
Future<Map<String, dynamic>> createHelpTicket(
    String titre, String message) async {
  final dio = await ApiClient.authed();
  try {
    final res = await dio.post('/help_create_ticket.php', data: {
      'titre': titre,
      'message': message,
    });
    return res.data;
  } on DioException catch (e) {
    return {'success': false, 'message': e.message};
  }
}
