import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const fallbackAppVersionInfo = AppVersionInfo(
  version: String.fromEnvironment('APP_VERSION', defaultValue: '1.0.1'),
  buildNumber: String.fromEnvironment('APP_BUILD_NUMBER', defaultValue: '5'),
);

final appVersionReaderProvider = Provider<AppVersionReader>((ref) {
  return const MethodChannelAppVersionReader();
});

final appVersionProvider = FutureProvider<AppVersionInfo>((ref) async {
  try {
    return await ref.read(appVersionReaderProvider).read();
  } on MissingPluginException {
    return fallbackAppVersionInfo;
  } on PlatformException {
    return fallbackAppVersionInfo;
  }
});

final class AppVersionInfo {
  const AppVersionInfo({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;
}

abstract interface class AppVersionReader {
  Future<AppVersionInfo> read();
}

final class MethodChannelAppVersionReader implements AppVersionReader {
  const MethodChannelAppVersionReader();

  static const _channel = MethodChannel('safe_wallet/app_info');

  @override
  Future<AppVersionInfo> read() async {
    final data = await _channel.invokeMapMethod<String, Object?>(
      'getAppVersion',
    );
    final version = data?['version'];
    final buildNumber = data?['buildNumber'];
    if (version is! String ||
        version.isEmpty ||
        buildNumber is! String ||
        buildNumber.isEmpty) {
      return fallbackAppVersionInfo;
    }
    return AppVersionInfo(version: version, buildNumber: buildNumber);
  }
}
