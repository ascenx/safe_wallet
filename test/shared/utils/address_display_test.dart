import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/shared/design/app_colors.dart';
import 'package:safe_wallet/shared/utils/address_display.dart';

void main() {
  group('highlightedAddressTextSpan', () {
    test('keeps the full address and highlights the first 4 and last 5 chars',
        () {
      const address = '0x9858effd232b4033e47d90003d41ec34ecaeda94';
      const baseStyle = TextStyle(color: Colors.black);

      final span = highlightedAddressTextSpan(
        address,
        style: baseStyle,
        highlightColor: AppColors.primary,
      );

      expect(span.toPlainText(), address);

      final children = span.children!.cast<TextSpan>();
      expect(children, hasLength(3));
      expect(children[0].text, address.substring(0, 4));
      expect(children[0].style?.color, AppColors.primary);
      expect(children[0].style?.fontWeight, FontWeight.w600);
      expect(children[1].text, address.substring(4, address.length - 5));
      expect(children[1].style?.color, baseStyle.color);
      expect(children[1].style?.fontWeight, baseStyle.fontWeight);
      expect(children[2].text, address.substring(address.length - 5));
      expect(children[2].style?.color, AppColors.primary);
      expect(children[2].style?.fontWeight, FontWeight.w600);
    });

    test('keeps short values unchanged and highlights the whole value', () {
      const address = '0x1234567';
      const baseStyle = TextStyle(color: Colors.black);

      final span = highlightedAddressTextSpan(
        address,
        style: baseStyle,
        highlightColor: AppColors.primary,
      );

      expect(span.toPlainText(), address);
      expect(span.style?.color, AppColors.primary);
      expect(span.style?.fontWeight, FontWeight.w600);
    });
  });
}
