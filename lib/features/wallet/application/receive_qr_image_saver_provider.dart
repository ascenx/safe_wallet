import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import 'receive_qr_image_saver.dart';

final receiveQrImageSaverProvider = Provider<ReceiveQrImageSaver>((ref) {
  return const GalleryReceiveQrImageSaver(GalReceiveQrGalleryGateway());
});

final class GalReceiveQrGalleryGateway implements ReceiveQrGalleryGateway {
  const GalReceiveQrGalleryGateway();

  @override
  Future<bool> hasAccess() => Gal.hasAccess();

  @override
  Future<void> requestAccess() async {
    await Gal.requestAccess();
  }

  @override
  Future<void> putImageBytes(
    Uint8List bytes, {
    required String fileName,
  }) async {
    try {
      await Gal.putImageBytes(bytes, name: fileName);
    } on GalException catch (error) {
      if (error.type == GalExceptionType.accessDenied) {
        throw const ReceiveQrImageSaveException(
          ReceiveQrImageSaveFailure.permissionDenied,
        );
      }
      rethrow;
    }
  }
}
