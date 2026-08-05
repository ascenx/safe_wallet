import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bundled token logos are compact real svg assets', () {
    _expectCompactRealSvgAssets(Directory('assets/token_logos'));
  });

  test('bundled chain logos are compact real svg assets', () {
    _expectCompactRealSvgAssets(Directory('assets/chain_logos'));
  });
}

void _expectCompactRealSvgAssets(Directory logoDirectory) {
  expect(logoDirectory.existsSync(), isTrue, reason: logoDirectory.path);
  final logoFiles = logoDirectory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.svg'))
      .toList()
    ..sort((left, right) => left.path.compareTo(right.path));

  expect(logoFiles, isNotEmpty);
  expect(
    logoDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.png')),
    isEmpty,
  );

  for (final logoFile in logoFiles) {
    final svg = logoFile.readAsStringSync();
    final fileName = logoFile.uri.pathSegments.last;

    expect(logoFile.lengthSync(), lessThan(24 * 1024), reason: fileName);
    expect(svg, isNot(contains('<image')), reason: fileName);
    expect(svg, isNot(contains('<style')), reason: fileName);
    expect(svg, isNot(contains('base64')), reason: fileName);
    expect(RegExp(r'<rect\b').allMatches(svg).length, lessThan(128),
        reason: fileName);
  }
}
