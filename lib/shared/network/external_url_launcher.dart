import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

final externalUrlLauncherProvider = Provider<ExternalUrlLauncher>((ref) {
  return const UrlLauncherExternalUrlLauncher();
});

abstract interface class ExternalUrlLauncher {
  Future<bool> openExternal(String url);
}

final class UrlLauncherExternalUrlLauncher implements ExternalUrlLauncher {
  const UrlLauncherExternalUrlLauncher();

  @override
  Future<bool> openExternal(String url) async {
    final normalized = url.trim();
    if (!isAllowedExternalUrl(normalized)) {
      return false;
    }
    final uri = Uri.parse(normalized);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

bool isAllowedExternalUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.isAbsolute || !uri.hasAuthority || uri.host.isEmpty) {
    return false;
  }
  return uri.scheme == 'https' || uri.scheme == 'http';
}
