import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/features/settings/application/app_update_checker.dart';

void main() {
  test(
    'compares semantic versions without treating v or build metadata as newer',
    () {
      expect(isVersionNewer(latest: 'v1.1.0', current: '1.0.9+12'), isTrue);
      expect(isVersionNewer(latest: 'v1.0.0', current: '1.0.0+1'), isFalse);
      expect(isVersionNewer(latest: 'v1.0.0', current: '1.1.0'), isFalse);
    },
  );

  test('compares semantic-version prerelease identifiers', () {
    expect(
      isVersionNewer(latest: '1.0.0-alpha.1', current: '1.0.0-alpha'),
      isTrue,
    );
    expect(
      isVersionNewer(latest: '1.0.0-beta', current: '1.0.0-alpha.9'),
      isTrue,
    );
    expect(
      isVersionNewer(latest: '1.0.0-rc.1', current: '1.0.0-beta.11'),
      isTrue,
    );
    expect(isVersionNewer(latest: '1.0.0', current: '1.0.0-rc.99'), isTrue);
    expect(isVersionNewer(latest: '1.0.0-alpha', current: '1.0.0'), isFalse);
  });

  test('compares numeric prerelease identifiers numerically', () {
    expect(
      isVersionNewer(latest: '1.0.0-alpha.10', current: '1.0.0-alpha.2'),
      isTrue,
    );
    expect(
      isVersionNewer(latest: '1.0.0-alpha.beta', current: '1.0.0-alpha.1'),
      isTrue,
    );
    expect(
      isVersionNewer(
        latest: '1.0.0-alpha.1+build.9',
        current: '1.0.0-alpha.1+build.1',
      ),
      isFalse,
    );
  });

  test('GitHub repository parses the latest stable release', () async {
    final repository = GitHubAppReleaseRepository(
      client: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.github.com/repos/ascenx/safe_wallet/releases/latest',
        );
        expect(request.headers['user-agent'], 'Safe-Wallet');
        return http.Response('''
          {
            "tag_name": "v1.2.0",
            "name": "Safe Wallet 1.2.0",
            "body": "Improved privacy controls",
            "html_url": "https://github.com/ascenx/safe_wallet/releases/tag/v1.2.0",
            "published_at": "2026-07-28T08:00:00Z",
            "draft": false,
            "prerelease": false
          }
          ''', 200);
      }),
    );

    final release = await repository.getLatestRelease();

    expect(release?.version, '1.2.0');
    expect(release?.title, 'Safe Wallet 1.2.0');
    expect(release?.notes, 'Improved privacy controls');
    expect(release?.publishedAt, DateTime.utc(2026, 7, 28, 8));
  });

  test('GitHub repository treats missing releases as no update', () async {
    final repository = GitHubAppReleaseRepository(
      client: MockClient((_) async => http.Response('{}', 404)),
    );

    expect(await repository.getLatestRelease(), isNull);
  });
}
