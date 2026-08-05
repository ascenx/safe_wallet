import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hive_browser_state_repository.dart';
import '../domain/dapp_recent_visit.dart';

typedef BrowserClock = DateTime Function();

final browserClockProvider = Provider<BrowserClock>((ref) {
  return () => DateTime.now().toUtc();
});

final dappRecentVisitsControllerProvider =
    AsyncNotifierProvider<DappRecentVisitsController, List<DappRecentVisit>>(
      DappRecentVisitsController.new,
    );

final class DappRecentVisitsController
    extends AsyncNotifier<List<DappRecentVisit>> {
  @override
  Future<List<DappRecentVisit>> build() {
    return ref.watch(browserStateRepositoryProvider).recentVisits();
  }

  Future<void> recordVisit({
    required String title,
    required String url,
    DateTime? visitedAt,
  }) async {
    final normalizedUrl = normalizeDappRecentVisitUrl(url);
    if (normalizedUrl == null) {
      throw ArgumentError.value(url, 'url', 'must be a valid http(s) URL');
    }
    final uri = Uri.parse(normalizedUrl);
    final visit = DappRecentVisit(
      domain: uri.host,
      title: title.trim().isEmpty ? uri.host : title.trim(),
      url: normalizedUrl,
      visitedAt: visitedAt ?? ref.read(browserClockProvider)(),
    );
    await ref.read(browserStateRepositoryProvider).saveRecentVisit(visit);
    state = AsyncData(
      await ref.read(browserStateRepositoryProvider).recentVisits(),
    );
  }
}

String? normalizeDappUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.contains(RegExp(r'\s'))) {
    return null;
  }

  final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(withScheme);
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty ||
      !uri.host.contains('.')) {
    return null;
  }
  return uri.toString();
}

String? normalizeDappRecentVisitUrl(String value) {
  final normalized = normalizeDappUrl(value);
  if (normalized == null) {
    return null;
  }
  final uri = Uri.parse(normalized);
  if (uri.userInfo.isNotEmpty) {
    return null;
  }
  final port = uri.hasPort && uri.port != 80 && uri.port != 443
      ? uri.port
      : null;
  return Uri(
    scheme: 'https',
    host: uri.host,
    port: port,
    path: uri.path,
  ).toString();
}

final class DappNavigationTarget {
  const DappNavigationTarget({required this.url, required this.isSearch});

  final String url;
  final bool isSearch;
}

DappNavigationTarget? resolveDappNavigationTarget(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final normalizedUrl = normalizeDappUrl(trimmed);
  if (normalizedUrl != null) {
    return DappNavigationTarget(url: normalizedUrl, isSearch: false);
  }
  return DappNavigationTarget(
    url: Uri.https('www.google.com', '/search', {'q': trimmed}).toString(),
    isSearch: true,
  );
}
