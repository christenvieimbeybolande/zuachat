// lib/api/albums_api.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'client.dart';

class AlbumsApi {
  // ===========================================================================
  // 🟥 ALBUMS DE L'UTILISATEUR CONNECTÉ (TOI)
  // ===========================================================================

  static Future<Map<String, dynamic>> fetchProfileAlbums() async {
    try {
      final dio = await ApiClient.authed();
      final res = await dio.get('/profile_albums.php');

      if (res.data['success'] == true) {
        return {
          'success': true,
          'data': Map<String, dynamic>.from(res.data['data'] ?? {})
        };
      }
      return {'success': false, 'message': res.data['message'] ?? "Erreur"};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> createAlbum(String nom) async {
    try {
      final dio = await ApiClient.authed();
      final res = await dio.post('/profile_albums.php',
          data: jsonEncode({'action': 'create', 'nom': nom}),
          options: Options(headers: {'Content-Type': 'application/json'}));
      return {
        'success': res.data['success'] == true,
        'message': res.data['message'] ?? ""
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> renameAlbum(int id, String nom) async {
    try {
      final dio = await ApiClient.authed();
      final res = await dio.post('/profile_albums.php',
          data: jsonEncode({'action': 'rename', 'id': id, 'nom': nom}),
          options: Options(headers: {'Content-Type': 'application/json'}));
      return {
        'success': res.data['success'] == true,
        'message': res.data['message'] ?? ""
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteAlbum(int id) async {
    try {
      final dio = await ApiClient.authed();
      final res = await dio.post('/profile_albums.php',
          data: jsonEncode({'action': 'delete', 'id': id}),
          options: Options(headers: {'Content-Type': 'application/json'}));
      return {
        'success': res.data['success'] == true,
        'message': res.data['message'] ?? ""
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ===========================================================================
  // 🟥 PHOTOS DE L'UTILISATEUR CONNECTÉ
  // ===========================================================================

  static Future<Map<String, dynamic>> fetchProfilePhotos() async {
    try {
      final dio = await ApiClient.authed();
      final res = await dio.get('/albums_profil.php');
      if (res.data['success'] == true) {
        return {
          'success': true,
          'photos': List<String>.from(res.data['photos'] ?? [])
        };
      }
      return {'success': false, 'message': res.data['message'] ?? ""};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> fetchCoverPhotos() async {
    try {
      final dio = await ApiClient.authed();
      final res = await dio.get('/albums_cover.php');
      if (res.data['success'] == true) {
        return {
          'success': true,
          'photos': List<String>.from(res.data['photos'] ?? [])
        };
      }
      return {'success': false, 'message': res.data['message'] ?? ""};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> fetchAllPhotos() async {
    try {
      final dio = await ApiClient.authed();
      final res = await dio.get('/albums_photos.php');
      if (res.data['success'] == true) {
        return {
          'success': true,
          'media': List<Map<String, dynamic>>.from(res.data['media'] ?? [])
        };
      }
      return {'success': false, 'message': res.data['message']};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<bool> deleteMedia(String url) async {
    try {
      final dio = await ApiClient.authed();
      final res =
          await dio.post('/albums_photos.php', data: {'deleteMedia': url});
      return res.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // ===========================================================================
  // 🟥 ALBUMS PERSONNALISÉS (connecté)
  // ===========================================================================

  static Future<Map<String, dynamic>> fetchCustomAlbumPhotos(int id) async {
    try {
      final dio = await ApiClient.authed();
      final res = await dio
          .get('/photos_albums_list.php', queryParameters: {'album_id': id});

      if (res.data['success'] == true) {
        return {
          'success': true,
          'photos': List<String>.from(res.data['photos'] ?? [])
        };
      }
      return {'success': false, 'message': res.data['message'] ?? ""};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<bool> deleteFromAlbum(int albumId, String file) async {
    try {
      final dio = await ApiClient.authed();
      final res = await dio.post('/photos_albums_actions.php',
          data: {'action': 'delete', 'album_id': albumId, 'file': file});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // ===========================================================================
  // 🟦 API VISITEUR : NOUVELLES ROUTES !!!
  // ===========================================================================

  /// 📌 Vue d’ensemble (profil, cover, all, custom)
  static Future<Map<String, dynamic>> fetchUserAlbums(int userId) async {
    try {
      final dio = ApiClient.raw();
      final res = await dio
          .get('/user_albums_overview.php', queryParameters: {'id': userId});

      if (res.data['success'] == true) {
        return {
          'success': true,
          'data': Map<String, dynamic>.from(res.data['data'] ?? {})
        };
      }
      return {'success': false, 'message': res.data['message']};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 📌 Photos de profil du visiteur
  static Future<Map<String, dynamic>> fetchProfilePhotosForUser(
      int userId) async {
    try {
      final dio = ApiClient.raw();
      final res = await dio
          .get('/user_album_profil.php', queryParameters: {'id': userId});

      if (res.data['success'] == true) {
        return {
          'success': true,
          'photos': List<String>.from(res.data['photos'] ?? [])
        };
      }
      return {'success': false, 'message': res.data['message']};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 📌 Photos de couverture du visiteur
  static Future<Map<String, dynamic>> fetchCoverPhotosForUser(
      int userId) async {
    try {
      final dio = ApiClient.raw();
      final res = await dio
          .get('/user_album_cover.php', queryParameters: {'id': userId});

      if (res.data['success'] == true) {
        return {
          'success': true,
          'photos': List<String>.from(res.data['photos'] ?? [])
        };
      }
      return {'success': false, 'message': res.data['message']};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 📌 Toutes les photos du visiteur (profil + cover + publications)
  static Future<Map<String, dynamic>> fetchAllPhotosForUser(int userId) async {
    try {
      final dio = ApiClient.raw();
      final res = await dio
          .get('/user_album_all_photos.php', queryParameters: {'id': userId});

      if (res.data['success'] == true) {
        return {
          'success': true,
          'photos': List<String>.from(res.data['photos'] ?? [])
        };
      }
      return {'success': false, 'message': res.data['message']};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 📌 Photos d’un album personnalisé du visiteur
  static Future<Map<String, dynamic>> fetchUserCustomAlbumPhotos(
      int userId, int albumId) async {
    try {
      final dio = ApiClient.raw();
      final res = await dio.get('/user_album_custom.php',
          queryParameters: {'id': userId, 'album_id': albumId});

      if (res.data['success'] == true) {
        return {
          'success': true,
          'photos': List<String>.from(res.data['photos'] ?? [])
        };
      }
      return {'success': false, 'message': res.data['message']};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ===========================================================================
  // 🟩 AJOUTER UNE PHOTO DU VISITEUR DANS MES ALBUMS
  // ===========================================================================

  static Future<Map<String, dynamic>> fetchMyAlbums() async {
    try {
      final dio = await ApiClient.authed();
      final res = await dio.get('/profile_albums.php');

      if (res.data['success'] == true) {
        return {
          'success': true,
          'albums': List<Map<String, dynamic>>.from(
            res.data['data']['albums_personnalises'] ?? [],
          )
        };
      }
      return {'success': false, 'message': res.data['message']};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> attachToAlbum(
      int albumId, String url) async {
    try {
      final dio = await ApiClient.authed();
      final res = await dio.post('/photos_albums_actions.php', data: {
        'action': 'attach',
        'album_id': albumId,
        'file_url': url,
      });

      return {
        'success': res.data['success'] == true,
        'message': res.data['message']
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
