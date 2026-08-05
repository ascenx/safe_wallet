import '../../chains/domain/chain_config.dart';

final class AddressBookContact {
  const AddressBookContact({
    required this.id,
    required this.name,
    required this.address,
    required this.chainType,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String address;
  final ChainType chainType;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AddressBookContact &&
            other.id == id &&
            other.name == name &&
            other.address == address &&
            other.chainType == chainType &&
            other.note == note &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      address,
      chainType,
      note,
      createdAt,
      updatedAt,
    );
  }
}
