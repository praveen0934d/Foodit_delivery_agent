import 'dart:convert';
import 'package:foodit_delivery_agent/config/api_client.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppConfigModel {
  final bool needsUpdate;
  final String updateUrl;

  AppConfigModel({required this.needsUpdate, required this.updateUrl});
}

abstract class ConfigRepository {
  Future<AppConfigModel> checkAppVersion();
}

class ConfigRepositoryImpl implements ConfigRepository {
  @override
  Future<AppConfigModel> checkAppVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = "${packageInfo.version}+${packageInfo.buildNumber}";

      final response = await ApiClient.requestWithRetry(() async {
        return await ApiClient.client.get(Uri.parse('https://inti11.sgcrguktsklm.org.in/api/version'))
            .timeout(const Duration(seconds: 10));
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String requiredVersion = data['deli_app'] ?? '';
        final String updateUrl = data['deli_url'] ?? '';

        if (currentVersion != requiredVersion) {
          return AppConfigModel(needsUpdate: true, updateUrl: updateUrl);
        }
      }
      return AppConfigModel(needsUpdate: false, updateUrl: '');
    } catch (e) {
      throw Exception('Failed to check app version: $e');
    }
  }
}
