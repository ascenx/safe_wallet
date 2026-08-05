import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production Dart files do not hardcode visible UI text', () {
    final violations = <String>[];
    final libDirectory = Directory('lib');
    final dartFiles = libDirectory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.startsWith('lib/i18n/generated/'));

    final hanLiteralPattern = RegExp(r'''(['"]).*[\u4e00-\u9fff].*\1''');
    final directVisibleLiteralPattern = RegExp(
      r'''(?:Text|SelectableText)\(\s*(['"])[^'"]+\1|'''
      r'''(?:labelText|hintText|helperText|errorText|semanticLabel|tooltip|title)\s*:\s*(['"])[^'"]+\2''',
    );

    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index];
        if (hanLiteralPattern.hasMatch(line) ||
            directVisibleLiteralPattern.hasMatch(line)) {
          violations.add('${file.path}:${index + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Visible UI strings should come from slang translations.',
    );
  });
}
