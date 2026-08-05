final class Caip2ChainId {
  const Caip2ChainId({required this.namespace, required this.reference});

  factory Caip2ChainId.parse(String value) {
    final parts = value.split(':');
    if (parts.length != 2 ||
        !_namespacePattern.hasMatch(parts[0]) ||
        !_referencePattern.hasMatch(parts[1])) {
      throw FormatException('Invalid CAIP-2 chain identifier', value);
    }
    return Caip2ChainId(namespace: parts[0], reference: parts[1]);
  }

  static final RegExp _namespacePattern = RegExp(r'^[a-z0-9-]{3,8}$');
  static final RegExp _referencePattern = RegExp(r'^[-_a-zA-Z0-9]{1,32}$');

  final String namespace;
  final String reference;

  @override
  String toString() => '$namespace:$reference';

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Caip2ChainId &&
            other.namespace == namespace &&
            other.reference == reference;
  }

  @override
  int get hashCode => Object.hash(namespace, reference);
}

final class Caip10AccountId {
  const Caip10AccountId({required this.chain, required this.address});

  factory Caip10AccountId.parse(String value) {
    final firstSeparator = value.indexOf(':');
    final secondSeparator = value.indexOf(':', firstSeparator + 1);
    if (firstSeparator <= 0 ||
        secondSeparator <= firstSeparator + 1 ||
        secondSeparator == value.length - 1) {
      throw FormatException('Invalid CAIP-10 account identifier', value);
    }
    final chain = Caip2ChainId.parse(value.substring(0, secondSeparator));
    final address = value.substring(secondSeparator + 1);
    if (address.length > 128 || !_addressPattern.hasMatch(address)) {
      throw FormatException('Invalid CAIP-10 account address', value);
    }
    return Caip10AccountId(chain: chain, address: address);
  }

  static final RegExp _addressPattern = RegExp(r'^[-.%a-zA-Z0-9]+$');

  final Caip2ChainId chain;
  final String address;

  bool matches({required Caip2ChainId chain, required String address}) {
    if (this.chain != chain) {
      return false;
    }
    if (chain.namespace == 'eip155') {
      return this.address.toLowerCase() == address.toLowerCase();
    }
    return this.address == address;
  }

  @override
  String toString() => '$chain:$address';

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Caip10AccountId &&
            other.chain == chain &&
            other.address == address;
  }

  @override
  int get hashCode => Object.hash(chain, address);
}
