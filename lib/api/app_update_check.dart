import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'client.dart';

class AppUpdateCheck {
  static Future<Map<String, dynamic>?> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final dio = ApiClient.raw();

      final res = await dio.get(
        "/app_update.php",
        queryParameters: {
          "platform": Platform.isAndroid ? "android" : "ios",
          "version": info.version,
        },
      );

      if (res.data is Map && res.data["ok"] == true) {
        return Map<String, dynamic>.from(res.data);
      }
    } catch (_) {}

    return null;
  }
}
