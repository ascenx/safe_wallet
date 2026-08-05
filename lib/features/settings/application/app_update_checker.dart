import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../shared/network/bounded_http_client.dart';
import 'app_version_provider.dart';

const safeWalletGitHubUrl = 'https://github.com/ascenx/safe_wallet';
const safeWalletReleasesUrl = '$safeWalletGitHubUrl/releases';
const safeWalletFeedbackUrl = '$safeWalletGitHubUrl/issues/new';

final appReleaseRepositoryProvider = Provider<AppReleaseRepository>((ref) {
  final client = BoundedHttpClient();
  ref.onDispose(client.close);
  return GitHubAppReleaseRepository(client: client);
});

final appUpdateCheckControllerProvider =
    AsyncNotifierProvider<AppUpdateCheckController, AppUpdateCheckResult?>(
      AppUpdateCheckController.new,
    );

final class AppReleaseInfo {
  const AppReleaseInfo({
    required this.version,
    required this.title,
    required this.notes,
    required this.url,
    this.publishedAt,
  });

  final String version;
  final String title;
  final String notes;
  final String url;
  final DateTime? publishedAt;
}

final class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.currentVersion,
    required this.latestRelease,
    required this.updateAvailable,
  });

  final AppVersionInfo currentVersion;
  final AppReleaseInfo? latestRelease;
  final bool updateAvailable;
}

abstract interface class AppReleaseRepository {
  Future<AppReleaseInfo?> getLatestRelease();
}

final class GitHubAppReleaseRepository implements AppReleaseRepository {
  GitHubAppReleaseRepository({required http.Client client}) : _client = client;

  final http.Client _client;

  @override
  Future<AppReleaseInfo?> getLatestRelease() async {
    final response = await _client
        .get(
          Uri.parse(
            'https://api.github.com/repos/ascenx/safe_wallet/releases/latest',
          ),
          headers: const {
            'accept': 'application/vnd.github+json',
            'x-github-api-version': '2022-11-28',
            'user-agent': 'Safe-Wallet',
          },
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('GitHub returned HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    if (data is! Map || data['draft'] == true || data['prerelease'] == true) {
      return null;
    }
    final tagName = data['tag_name'];
    final url = data['html_url'];
    if (tagName is! String ||
        tagName.isEmpty ||
        url is! String ||
        url.isEmpty) {
      throw const FormatException('Invalid GitHub release payload');
    }
    return AppReleaseInfo(
      version: _normalizedVersion(tagName),
      title: data['name'] is String && (data['name'] as String).isNotEmpty
          ? data['name'] as String
          : tagName,
      notes: data['body'] is String ? data['body'] as String : '',
      url: url,
      publishedAt: DateTime.tryParse(data['published_at'] as String? ?? ''),
    );
  }
}

final class AppUpdateCheckController
    extends AsyncNotifier<AppUpdateCheckResult?> {
  @override
  Future<AppUpdateCheckResult?> build() async => null;

  Future<AppUpdateCheckResult> check() async {
    state = const AsyncLoading();
    try {
      final currentVersion = await ref.read(appVersionProvider.future);
      final release = await ref
          .read(appReleaseRepositoryProvider)
          .getLatestRelease();
      final result = AppUpdateCheckResult(
        currentVersion: currentVersion,
        latestRelease: release,
        updateAvailable:
            release != null &&
            isVersionNewer(
              latest: release.version,
              current: currentVersion.version,
            ),
      );
      state = AsyncData(result);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

bool isVersionNewer({required String latest, required String current}) {
  final latestVersion = _SemanticVersion.tryParse(latest);
  final currentVersion = _SemanticVersion.tryParse(current);
  if (latestVersion == null || currentVersion == null) {
    return false;
  }
  return latestVersion.compareTo(currentVersion) > 0;
}

String _normalizedVersion(String value) {
  return value.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
}

final class _SemanticVersion implements Comparable<_SemanticVersion> {
  const _SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.prerelease,
  });

  static final _pattern = RegExp(
    r'^[vV]?([0-9]+)\.([0-9]+)\.([0-9]+)'
    r'(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
    r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );

  final BigInt major;
  final BigInt minor;
  final BigInt patch;
  final List<String>? prerelease;

  static _SemanticVersion? tryParse(String value) {
    final match = _pattern.firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    final major = match.group(1)!;
    final minor = match.group(2)!;
    final patch = match.group(3)!;
    if (_hasNumericLeadingZero(major) ||
        _hasNumericLeadingZero(minor) ||
        _hasNumericLeadingZero(patch)) {
      return null;
    }
    final prerelease = match.group(4)?.split('.');
    if (prerelease != null &&
        prerelease.any(
          (identifier) =>
              _isNumeric(identifier) && _hasNumericLeadingZero(identifier),
        )) {
      return null;
    }
    return _SemanticVersion(
      major: BigInt.parse(major),
      minor: BigInt.parse(minor),
      patch: BigInt.parse(patch),
      prerelease: prerelease,
    );
  }

  @override
  int compareTo(_SemanticVersion other) {
    final coreComparison = _compareCore(other);
    if (coreComparison != 0) {
      return coreComparison;
    }
    final leftPrerelease = prerelease;
    final rightPrerelease = other.prerelease;
    if (leftPrerelease == null) {
      return rightPrerelease == null ? 0 : 1;
    }
    if (rightPrerelease == null) {
      return -1;
    }
    final length = leftPrerelease.length < rightPrerelease.length
        ? leftPrerelease.length
        : rightPrerelease.length;
    for (var index = 0; index < length; index += 1) {
      final comparison = _comparePrereleaseIdentifier(
        leftPrerelease[index],
        rightPrerelease[index],
      );
      if (comparison != 0) {
        return comparison;
      }
    }
    return leftPrerelease.length.compareTo(rightPrerelease.length);
  }

  int _compareCore(_SemanticVersion other) {
    final majorComparison = major.compareTo(other.major);
    if (majorComparison != 0) {
      return majorComparison;
    }
    final minorComparison = minor.compareTo(other.minor);
    return minorComparison != 0
        ? minorComparison
        : patch.compareTo(other.patch);
  }
}

int _comparePrereleaseIdentifier(String left, String right) {
  final leftNumeric = _isNumeric(left);
  final rightNumeric = _isNumeric(right);
  if (leftNumeric && rightNumeric) {
    return BigInt.parse(left).compareTo(BigInt.parse(right));
  }
  if (leftNumeric != rightNumeric) {
    return leftNumeric ? -1 : 1;
  }
  return left.compareTo(right);
}

bool _isNumeric(String value) => RegExp(r'^[0-9]+$').hasMatch(value);

bool _hasNumericLeadingZero(String value) {
  return value.length > 1 && value.startsWith('0');
}
