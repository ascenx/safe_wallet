import '../domain/dapp_entry.dart';
import 'default_dapp_catalog.dart';

abstract interface class DappCatalogRepository {
  Future<List<DappEntry>> listDapps();
}

final class DefaultDappCatalogRepository implements DappCatalogRepository {
  const DefaultDappCatalogRepository();

  @override
  Future<List<DappEntry>> listDapps() async {
    return List.unmodifiable(defaultDappCatalog);
  }
}
