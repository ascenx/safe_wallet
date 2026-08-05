import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production TextFields disable spell check and autocorrect', () {
    final violations = <String>[];
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.startsWith('lib/i18n/generated/'));

    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      for (final constructor in _findTextFieldConstructors(source)) {
        final textFieldSource = source.substring(
          constructor.start,
          constructor.end,
        );
        final hasSpellCheckDisabled = RegExp(
          r'spellCheckConfiguration:\s*SpellCheckConfiguration\.disabled\(\)',
        ).hasMatch(textFieldSource);
        final hasAutocorrectDisabled = textFieldSource.contains(
          'autocorrect: false',
        );
        if (!hasSpellCheckDisabled || !hasAutocorrectDisabled) {
          violations.add(
            '${file.path}:${_lineNumber(source, constructor.start)}',
          );
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'TextField should explicitly disable spell check and autocorrect.',
    );
  });
}

Iterable<({int start, int end})> _findTextFieldConstructors(
    String source) sync* {
  final pattern = RegExp(r'\bTextField\s*\(');
  for (final match in pattern.allMatches(source)) {
    final openParen = source.indexOf('(', match.start);
    final end = _findMatchingParen(source, openParen);
    if (end != null) {
      yield (start: match.start, end: end + 1);
    }
  }
}

int? _findMatchingParen(String source, int openParen) {
  var depth = 0;
  String? quote;
  var isEscaped = false;

  for (var index = openParen; index < source.length; index += 1) {
    final char = source[index];
    if (quote != null) {
      if (isEscaped) {
        isEscaped = false;
      } else if (char == r'\') {
        isEscaped = true;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }

    if (char == '\'' || char == '"') {
      quote = char;
    } else if (char == '(') {
      depth += 1;
    } else if (char == ')') {
      depth -= 1;
      if (depth == 0) {
        return index;
      }
    }
  }

  return null;
}

int _lineNumber(String source, int offset) {
  return '\n'.allMatches(source.substring(0, offset)).length + 1;
}
