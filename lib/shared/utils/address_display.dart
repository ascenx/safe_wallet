import 'package:flutter/material.dart';

String middleEllipsizedAddress(
  String address, {
  int leadingLength = 12,
  int trailingLength = 12,
}) {
  if (address.length <= leadingLength + trailingLength) {
    return address;
  }
  return '${address.substring(0, leadingLength)}…'
      '${address.substring(address.length - trailingLength)}';
}

TextSpan highlightedAddressTextSpan(
  String address, {
  required TextStyle style,
  required Color highlightColor,
}) {
  const prefixLength = 4;
  const suffixLength = 5;
  if (address.length <= prefixLength + suffixLength) {
    return TextSpan(
      text: address,
      style: _highlightStyle(style, highlightColor),
    );
  }

  return TextSpan(
    children: [
      TextSpan(
        text: address.substring(0, prefixLength),
        style: _highlightStyle(style, highlightColor),
      ),
      TextSpan(
        text: address.substring(prefixLength, address.length - suffixLength),
        style: style,
      ),
      TextSpan(
        text: address.substring(address.length - suffixLength),
        style: _highlightStyle(style, highlightColor),
      ),
    ],
  );
}

TextStyle _highlightStyle(TextStyle style, Color highlightColor) {
  return style.copyWith(
    color: highlightColor,
    fontWeight: FontWeight.w600,
  );
}
