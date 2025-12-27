import 'package:dio/dio.dart';
import 'client.dart';

/// ===============================================================
/// 📌 Récupération propre et finalisée des conversations
/// ===============================================================
Future<List<Map<String, dynamic>>> apiFetchConversations() async {
  final dio = await ApiClient.authed();

  final Response res = await dio.get('/messages_list.php');
  final body = res.data;

  // --- Vérification structure ---
  if (body is! Map || body['ok'] != true) {
    final msg = body is Map && body['error'] != null
        ? body['error'].toString()
        : 'Erreur de chargement des conversations';
    throw Exception(msg);
  }

  final List rawList = body['data']?['conversations'] ?? [];

  // ======================================================
  // 🔥 Conversion propre des données
  // ======================================================
  return rawList.map<Map<String, dynamic>>((e) {
    final map = Map<String, dynamic>.from(e as Map);

    // ------------------------------
    // 👤 FULL NAME (professionnel / personnel)
    // ------------------------------
    final typeCompte = (map['type_compte'] ?? '').toString();
    String fullname;

    if (typeCompte == 'professionnel') {
      fullname = (map['nom'] ?? '').toString();
    } else {
      final prenom = (map['prenom'] ?? '').toString();
      final postnom = (map['postnom'] ?? '').toString();
      final nom = (map['nom'] ?? '').toString();

      fullname = "$prenom $postnom $nom".trim();
    }

    if (fullname.isEmpty) fullname = "Utilisateur";

    // ------------------------------
    // 🖼️ PHOTO
    // ------------------------------
    String photo = (map['photo'] ?? '').toString();

    if (photo.isEmpty) {
      photo = "https://zuachat.com/assets/default-avatar.png";
    } else if (!photo.startsWith("http")) {
      photo = "https://zuachat.com/$photo";
    }

    // ------------------------------
    // 🔔 UNREAD
    // ------------------------------
    final unread = int.tryParse("${map['unread_count'] ?? 0}") ?? 0;

    // ------------------------------
    // 🕒 LAST MESSAGE TIME
    // ------------------------------
    final lastMsg = (map['last_msg_time'] ?? '').toString();

    // ------------------------------
    // VERIFICATION BADGE
    // ------------------------------
    final verified = map['badge_verified'].toString() == "1";

    return {
      "partner_id": map["partner_id"],
      "fullname": fullname,
      "photo": photo,
      "badge_verified": verified,
      "unread_count": unread,
      "last_msg_time": lastMsg,
    };
  }).toList();
}
