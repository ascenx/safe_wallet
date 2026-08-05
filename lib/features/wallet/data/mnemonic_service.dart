import 'package:bip39_mnemonic/bip39_mnemonic.dart';

final class MnemonicService {
  const MnemonicService();

  String generateMnemonic({
    MnemonicLength length = MnemonicLength.words12,
  }) {
    return Mnemonic.generate(Language.english, length: length).sentence;
  }

  Mnemonic parseMnemonic(String sentence) {
    try {
      return Mnemonic.fromSentence(
        _normalizeSentence(sentence),
        Language.english,
      );
    } on MnemonicException catch (error) {
      throw ArgumentError.value(sentence, 'sentence', error.toString());
    }
  }

  bool isValidMnemonic(String sentence) {
    try {
      parseMnemonic(sentence);
      return true;
    } on ArgumentError {
      return false;
    }
  }

  String _normalizeSentence(String sentence) {
    return sentence.trim().split(RegExp(r'\s+')).join(' ');
  }
}
