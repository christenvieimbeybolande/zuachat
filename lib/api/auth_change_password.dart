import 'package:dio/dio.dart';
import 'client.dart';

/// =======================================================
/// 🔐 Vérifier l’ancien mot de passe
/// =======================================================
Future<bool> apiCheckOldPassword(String oldPassword) async {
  final dio = await ApiClient.authed(); // ✅ CORRECT

  try {
    final res = await dio.post(
      '/auth_change_password.php',
      data: {
        'old_password': oldPassword,
        'check_only': true,
      },
    );

    if (res.data['ok'] == true) {
      return true;
    }

    throw Exception(
      res.data['error']?['message'] ?? 'Ancien mot de passe incorrect.',
    );
  } on DioException catch (e) {
    throw Exception(
      e.response?.data?['error']?['message'] ??
          'Erreur réseau lors de la vérification.',
    );
  }
}

/// =======================================================
/// 🔄 Changer le mot de passe
/// =======================================================
Future<void> apiChangePassword(String newPassword) async {
  final dio = await ApiClient.authed(); // ✅ CORRECT

  try {
    final res = await dio.post(
      '/auth_change_password.php',
      data: {
        'new_password': newPassword,
      },
    );

    if (res.data['ok'] != true) {
      throw Exception(
        res.data['error']?['message'] ??
            'Erreur lors du changement du mot de passe.',
      );
    }
  } on DioException catch (e) {
    throw Exception(
      e.response?.data?['error']?['message'] ??
          'Erreur réseau lors du changement du mot de passe.',
    );
  }
}
