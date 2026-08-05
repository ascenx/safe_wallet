import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/assets/presentation/widgets/token_icon.dart';

void main() {
  testWidgets('renders svg asset logos with SvgPicture', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TokenIcon(
            symbol: 'USDT',
            logoUri: 'asset:assets/token_logos/usdt.svg',
          ),
        ),
      ),
    );

    expect(find.byType(SvgPicture), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(find.byType(CircleAvatar), findsNothing);
  });

  testWidgets('uses contain fit for svg logos to avoid cropping tall assets', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TokenIcon(
            symbol: 'ETH',
            logoUri: 'asset:assets/token_logos/eth.svg',
          ),
        ),
      ),
    );

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));

    expect(svg.fit, BoxFit.contain);
  });

  testWidgets('renders every bundled svg logo without fallback', (
    tester,
  ) async {
    final logoFiles =
        Directory('assets/token_logos')
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.svg'))
            .toList()
          ..sort((left, right) => left.path.compareTo(right.path));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: [
              for (final logoFile in logoFiles)
                TokenIcon(
                  symbol: logoFile.uri.pathSegments.last,
                  logoUri: 'asset:${logoFile.path}',
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(SvgPicture), findsNWidgets(logoFiles.length));
    await tester.pumpAndSettle();

    expect(find.byType(CircleAvatar), findsNothing);
  });

  testWidgets('rejects insecure remote logos without a network image', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TokenIcon(
            symbol: 'SCAM',
            logoUri: 'http://127.0.0.1/token.svg',
          ),
        ),
      ),
    );

    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.byType(Image), findsNothing);
  });
}
