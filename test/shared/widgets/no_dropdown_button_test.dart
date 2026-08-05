import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production UI uses bottom sheets instead of dropdown buttons', () {
    final violations = <String>[];
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.startsWith('lib/i18n/generated/'));

    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index];
        if (line.contains('DropdownButtonFormField') ||
            RegExp(r'\bDropdownButton\s*<').hasMatch(line)) {
          violations.add('${file.path}:${index + 1}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Use AppPickerField with showAppActionSheet for selections.',
    );
  });
}
