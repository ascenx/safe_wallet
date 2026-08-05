import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../shared/design/app_colors.dart';
import '../../../../shared/design/app_brand_colors.dart';
import '../../../../shared/design/app_text_styles.dart';
import '../../../../shared/network/safe_remote_image_loader.dart';

const _tokenLogoFit = BoxFit.contain;

final class TokenIcon extends StatelessWidget {
  const TokenIcon({
    required this.symbol,
    this.logoUri,
    this.size = 40,
    this.muted = false,
    this.logoKeyPrefix,
    this.fallbackKeyPrefix,
    super.key,
  });

  final String symbol;
  final String? logoUri;
  final double size;
  final bool muted;
  final String? logoKeyPrefix;
  final String? fallbackKeyPrefix;

  @override
  Widget build(BuildContext context) {
    final normalizedLogoUri = _normalizedLogoUri(logoUri);
    if (normalizedLogoUri == null) {
      return _fallback(context);
    }
    return ClipOval(
      key: _key(logoKeyPrefix),
      child: SizedBox.square(
        dimension: size,
        child: _logoImage(context, normalizedLogoUri),
      ),
    );
  }

  Widget _logoImage(BuildContext context, String normalizedLogoUri) {
    final remoteUri = safeRemoteImageUri(normalizedLogoUri);
    final image = remoteUri != null
        ? _RemoteTokenLogo(
            url: remoteUri.toString(),
            size: size,
            fallback: _fallback(context),
          )
        : _isNetworkLogo(normalizedLogoUri)
        ? _fallback(context)
        : _isSvgLogo(normalizedLogoUri)
        ? _svgLogo(context, normalizedLogoUri)
        : _rasterLogo(context, normalizedLogoUri);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: muted
            ? context.appColors.surfaceSoft
            : context.brandColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: image,
    );
  }

  Widget _svgLogo(BuildContext context, String normalizedLogoUri) {
    return SvgPicture.asset(
      normalizedLogoUri,
      fit: _tokenLogoFit,
      placeholderBuilder: (_) => _fallback(context),
      errorBuilder: (_, _, _) => _fallback(context),
    );
  }

  Widget _rasterLogo(BuildContext context, String normalizedLogoUri) {
    return Image.asset(
      normalizedLogoUri,
      fit: _tokenLogoFit,
      errorBuilder: (_, _, _) => _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) {
    return CircleAvatar(
      key: _key(fallbackKeyPrefix),
      radius: size / 2,
      backgroundColor: muted
          ? context.appColors.surfaceSoft
          : context.brandColors.primarySoft,
      foregroundColor: muted
          ? context.appColors.textMuted
          : Theme.of(context).colorScheme.primary,
      child: Text(
        symbol.isEmpty ? '?' : symbol.substring(0, 1),
        style: size >= 48 ? context.appTextStyles.titleMedium : null,
      ),
    );
  }

  String? _normalizedLogoUri(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (trimmed.startsWith('asset:')) {
      return trimmed.substring('asset:'.length);
    }
    return trimmed;
  }

  bool _isNetworkLogo(String normalizedLogoUri) {
    return normalizedLogoUri.startsWith('http://') ||
        normalizedLogoUri.startsWith('https://');
  }

  bool _isSvgLogo(String normalizedLogoUri) {
    return normalizedLogoUri.split('?').first.toLowerCase().endsWith('.svg');
  }

  Key? _key(String? prefix) {
    return prefix == null ? null : Key('$prefix.$symbol');
  }
}

final class _RemoteTokenLogo extends StatefulWidget {
  const _RemoteTokenLogo({
    required this.url,
    required this.size,
    required this.fallback,
  });

  final String url;
  final double size;
  final Widget fallback;

  @override
  State<_RemoteTokenLogo> createState() => _RemoteTokenLogoState();
}

final class _RemoteTokenLogoState extends State<_RemoteTokenLogo> {
  late Future<SafeRemoteImageData?> _image;

  @override
  void initState() {
    super.initState();
    _image = SafeRemoteImageLoader.shared.load(widget.url);
  }

  @override
  void didUpdateWidget(_RemoteTokenLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _image = SafeRemoteImageLoader.shared.load(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SafeRemoteImageData?>(
      future: _image,
      builder: (context, snapshot) {
        final image = snapshot.data;
        if (image == null) {
          return widget.fallback;
        }
        if (image.isSvg) {
          return SvgPicture.memory(
            image.bytes,
            fit: _tokenLogoFit,
            errorBuilder: (_, _, _) => widget.fallback,
          );
        }
        final pixelSize = (widget.size * MediaQuery.devicePixelRatioOf(context))
            .ceil();
        return Image.memory(
          image.bytes,
          fit: _tokenLogoFit,
          cacheWidth: pixelSize,
          cacheHeight: pixelSize,
          errorBuilder: (_, _, _) => widget.fallback,
        );
      },
    );
  }
}
