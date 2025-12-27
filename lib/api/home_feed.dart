import 'package:dio/dio.dart';
import 'client.dart'; // ApiClient.authed()

/// ===========================================================
/// 🏡 HOME FEED ZuaChat (Flutter)
/// - Pagination
/// - Normalisation des données
/// - BADGES notifications & messages non lus
/// ===========================================================
/// Retourne :
/// {
///   ok: true,
///   unread_notifications: 3,
///   unread_messages: 1,
///   user: {},
///   statuts: [],
///   publications: [],
///   sponsorises: [],
///   page: 1,
///   limit: 20
/// }
/// ===========================================================

Future<Map<String, dynamic>> fetchHomeFeed({
  int page = 1,
  int limit = 20,
}) async {
  final dio = await ApiClient.authed();

  try {
    print("📡 [HOME FEED] ➝ /home_feed.php?page=$page&limit=$limit");

    final res = await dio.get(
      "/home_feed.php",
      queryParameters: {
        "page": page,
        "limit": limit,
      },
    );

    // -------------------------------
    // ✅ RÉPONSE OK
    // -------------------------------
    if (res.statusCode == 200 && res.data is Map && res.data["ok"] == true) {
      final root = Map<String, dynamic>.from(res.data);

      // 🔔 BADGES GLOBAUX (IMPORTANT)
      final int unreadNotifications =
          int.tryParse("${root["unread_notifications"] ?? 0}") ?? 0;

      final int unreadMessages =
          int.tryParse("${root["unread_messages"] ?? 0}") ?? 0;

      // 📦 CONTENU DU FEED
      final data = Map<String, dynamic>.from(root["data"] ?? {});

      final user = Map<String, dynamic>.from(data["user"] ?? {});

      final statuts = List<Map<String, dynamic>>.from(
        (data["statuts"] ?? []).whereType<Map>(),
      );

      final publications = List<Map<String, dynamic>>.from(
        (data["publications"] ?? []).whereType<Map>(),
      );

      final sponsorises = List<Map<String, dynamic>>.from(
        (data["sponsorises"] ?? []).whereType<Map>(),
      );

      // -------------------------------
      // ✅ OBJET FINAL UTILISÉ PAR LE FEED
      // -------------------------------
      return {
        "ok": true,

        // 🔔 BADGES
        "unread_notifications": unreadNotifications,
        "unread_messages": unreadMessages,

        // 📦 DATA
        "user": user,
        "statuts": statuts,
        "publications": publications,
        "sponsorises": sponsorises,

        // 📄 PAGINATION
        "page": root["page"] ?? page,
        "limit": root["limit"] ?? limit,
      };
    }

    // -------------------------------
    // ❌ RÉPONSE INVALIDE
    // -------------------------------
    return {
      "ok": false,
      "error": "Réponse invalide du serveur",
    };
  }

  // -------------------------------
  // ❌ ERREUR DIO
  // -------------------------------
  on DioException catch (e) {
    final msg = e.response?.data ?? e.message ?? "Erreur API inconnue";
    print("❌ [HOME FEED] $msg");

    return {
      "ok": false,
      "error": msg,
    };
  }

  // -------------------------------
  // ❌ AUTRE ERREUR
  // -------------------------------
  catch (e) {
    print("💥 [HOME FEED] Exception : $e");
    return {
      "ok": false,
      "error": "$e",
    };
  }
}
