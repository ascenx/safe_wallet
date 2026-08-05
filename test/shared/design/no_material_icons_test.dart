import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('application code uses the shared icon system instead of Material Icons',
      () {
    final violations = <String>[];
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        if (RegExp(r'\bIcons\.').hasMatch(lines[index])) {
          violations.add('${file.path}:${index + 1}: ${lines[index].trim()}');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('phosphor icon package is declared', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('phosphor_flutter:'));
  });
}
