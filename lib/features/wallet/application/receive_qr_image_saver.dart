import 'dart:typed_data';

enum ReceiveQrImageSaveFailure { permissionDenied, saveFailed }

final class ReceiveQrImageSaveException implements Exception {
  const ReceiveQrImageSaveException(this.failure);

  final ReceiveQrImageSaveFailure failure;
}

abstract interface class ReceiveQrImageSaver {
  Future<void> save(Uint8List bytes, {required String fileName});
}

abstract interface class ReceiveQrGalleryGateway {
  Future<bool> hasAccess();

  Future<void> requestAccess();

  Future<void> putImageBytes(
    Uint8List bytes, {
    required String fileName,
  });
}

final class GalleryReceiveQrImageSaver implements ReceiveQrImageSaver {
  const GalleryReceiveQrImageSaver(this._gateway);

  final ReceiveQrGalleryGateway _gateway;

  @override
  Future<void> save(Uint8List bytes, {required String fileName}) async {
    bool hasAccess;
    try {
      hasAccess = await _gateway.hasAccess();
      if (!hasAccess) {
        await _gateway.requestAccess();
        hasAccess = await _gateway.hasAccess();
      }
    } catch (_) {
      throw const ReceiveQrImageSaveException(
        ReceiveQrImageSaveFailure.permissionDenied,
      );
    }

    if (!hasAccess) {
      throw const ReceiveQrImageSaveException(
        ReceiveQrImageSaveFailure.permissionDenied,
      );
    }

    try {
      await _gateway.putImageBytes(bytes, fileName: fileName);
    } on ReceiveQrImageSaveException {
      rethrow;
    } catch (_) {
      throw const ReceiveQrImageSaveException(
        ReceiveQrImageSaveFailure.saveFailed,
      );
    }
  }
}
