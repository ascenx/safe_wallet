import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dappProviderDocumentStartInjectorProvider =
    Provider<DappProviderDocumentStartInjector>(
  (ref) => const MethodChannelDappProviderDocumentStartInjector(),
);

abstract interface class DappProviderDocumentStartInjector {
  Future<bool> install({
    required Object controller,
    required String source,
  });
}

final class MethodChannelDappProviderDocumentStartInjector
    implements DappProviderDocumentStartInjector {
  const MethodChannelDappProviderDocumentStartInjector({
    MethodChannel channel = _defaultChannel,
  }) : _channel = channel;

  static const _defaultChannel = MethodChannel('safe_wallet/webview');

  final MethodChannel _channel;

  @override
  Future<bool> install({
    required Object controller,
    required String source,
  }) async {
    final webViewIdentifier = _webViewIdentifier(controller);
    if (webViewIdentifier == null || source.isEmpty) {
      debugPrint(
        '[SafeWalletDapp] document-start install skipped '
        'reason=${webViewIdentifier == null ? 'missing_webview_identifier' : 'empty_source'} '
        'sourceLength=${source.length}',
      );
      return false;
    }

    try {
      debugPrint(
        '[SafeWalletDapp] document-start install request '
        'webViewIdentifier=$webViewIdentifier sourceLength=${source.length}',
      );
      await _channel.invokeMethod<void>('addDocumentStartScript', {
        'webViewIdentifier': webViewIdentifier,
        'source': source,
      });
      debugPrint(
        '[SafeWalletDapp] document-start install success '
        'webViewIdentifier=$webViewIdentifier',
      );
      return true;
    } on MissingPluginException catch (error) {
      debugPrint(
        '[SafeWalletDapp] document-start install missing plugin '
        'webViewIdentifier=$webViewIdentifier error=$error',
      );
      return false;
    } on PlatformException catch (error) {
      debugPrint(
        '[SafeWalletDapp] document-start install platform error '
        'webViewIdentifier=$webViewIdentifier code=${error.code} '
        'message=${error.message}',
      );
      return false;
    }
  }

  int? _webViewIdentifier(Object controller) {
    try {
      final value = (controller as dynamic).webViewIdentifier;
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
