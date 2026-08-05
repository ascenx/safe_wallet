import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/wallet/application/receive_qr_image_saver.dart';

void main() {
  group('GalleryReceiveQrImageSaver', () {
    test('requests access before writing image bytes', () async {
      final gateway = _FakeReceiveQrGalleryGateway(
        accessResults: [false, true],
      );
      final saver = GalleryReceiveQrImageSaver(gateway);
      final bytes = Uint8List.fromList([1, 2, 3]);

      await saver.save(bytes, fileName: 'safe-wallet-evm-receive-1.png');

      expect(gateway.requestAccessCallCount, 1);
      expect(gateway.savedBytes, bytes);
      expect(gateway.savedFileName, 'safe-wallet-evm-receive-1.png');
    });

    test('reports permission denial when access remains unavailable', () async {
      final gateway = _FakeReceiveQrGalleryGateway(
        accessResults: [false, false],
      );
      final saver = GalleryReceiveQrImageSaver(gateway);

      expect(
        () => saver.save(
          Uint8List.fromList([1]),
          fileName: 'safe-wallet-evm-receive-1.png',
        ),
        throwsA(
          isA<ReceiveQrImageSaveException>().having(
            (error) => error.failure,
            'failure',
            ReceiveQrImageSaveFailure.permissionDenied,
          ),
        ),
      );
      expect(gateway.savedBytes, isNull);
    });

    test('reports save failure when the gallery write throws', () async {
      final gateway = _FakeReceiveQrGalleryGateway(
        accessResults: [true],
        putError: StateError('write failed'),
      );
      final saver = GalleryReceiveQrImageSaver(gateway);

      expect(
        () => saver.save(
          Uint8List.fromList([1]),
          fileName: 'safe-wallet-evm-receive-1.png',
        ),
        throwsA(
          isA<ReceiveQrImageSaveException>().having(
            (error) => error.failure,
            'failure',
            ReceiveQrImageSaveFailure.saveFailed,
          ),
        ),
      );
    });

    test('preserves permission denial reported during the gallery write', () {
      final gateway = _FakeReceiveQrGalleryGateway(
        accessResults: [true],
        putError: const ReceiveQrImageSaveException(
          ReceiveQrImageSaveFailure.permissionDenied,
        ),
      );
      final saver = GalleryReceiveQrImageSaver(gateway);

      expect(
        () => saver.save(
          Uint8List.fromList([1]),
          fileName: 'safe-wallet-evm-receive-1.png',
        ),
        throwsA(
          isA<ReceiveQrImageSaveException>().having(
            (error) => error.failure,
            'failure',
            ReceiveQrImageSaveFailure.permissionDenied,
          ),
        ),
      );
    });
  });
}

final class _FakeReceiveQrGalleryGateway implements ReceiveQrGalleryGateway {
  _FakeReceiveQrGalleryGateway({
    required List<bool> accessResults,
    this.putError,
  }) : _accessResults = [...accessResults];

  final List<bool> _accessResults;
  final Object? putError;
  int requestAccessCallCount = 0;
  Uint8List? savedBytes;
  String? savedFileName;

  @override
  Future<bool> hasAccess() async => _accessResults.removeAt(0);

  @override
  Future<void> requestAccess() async {
    requestAccessCallCount += 1;
  }

  @override
  Future<void> putImageBytes(
    Uint8List bytes, {
    required String fileName,
  }) async {
    if (putError != null) {
      throw putError!;
    }
    savedBytes = bytes;
    savedFileName = fileName;
  }
}
