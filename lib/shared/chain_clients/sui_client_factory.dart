import 'package:grpc/grpc.dart';
import 'package:sui_dart/grpc/generated/sui/rpc/v2/ledger_service.pb.dart';
import 'package:sui_dart/grpc/sui_grpc_client.dart';

import '../errors/rpc_error.dart';
import '../network/grpc_client_channel.dart';

const suiMainnetChainIdentifier =
    '4btiuiMPvEENsttpZC7CZ53DruC3MAgfznDbASZ7DR6S';
const suiTestnetChainIdentifier =
    '69WiPg3DAQiwdxfncX6wYQ2siKwAe6L9BZthQea3JNMD';

String? expectedSuiChainIdentifier(String chainId) {
  return switch (chainId) {
    'sui:mainnet' => suiMainnetChainIdentifier,
    'sui:testnet' => suiTestnetChainIdentifier,
    _ => null,
  };
}

final class SuiServiceInfo {
  const SuiServiceInfo({
    required this.chainIdentifier,
    required this.network,
    required this.checkpointHeight,
  });

  final String chainIdentifier;
  final String network;
  final int checkpointHeight;
}

abstract interface class SuiClientFactory {
  Future<SuiServiceInfo> getServiceInfo(
    String rpcUrl, {
    Map<String, String> headers = const {},
  });
}

final class GrpcSuiClientFactory implements SuiClientFactory {
  const GrpcSuiClientFactory();

  @override
  Future<SuiServiceInfo> getServiceInfo(
    String rpcUrl, {
    Map<String, String> headers = const {},
  }) async {
    final endpoint = _parseGrpcEndpoint(rpcUrl);
    final client = SuiGrpcClient(
      SuiGrpcClientOptions(
        baseUrl: endpoint.host,
        port: endpoint.port,
        customChannel: DefaultCallOptionsClientChannel(
          endpoint.host,
          port: endpoint.port,
          headers: headers,
        ),
      ),
    );
    try {
      final response = await client.ledgerService.getServiceInfo(
        GetServiceInfoRequest(),
      );
      if (response.chainId.isEmpty || response.checkpointHeight.isNegative) {
        throw const RpcError.unavailable(
          debugMessage: 'Sui gRPC service info is invalid',
        );
      }
      return SuiServiceInfo(
        chainIdentifier: response.chainId,
        network: response.chain,
        checkpointHeight: response.checkpointHeight.toInt(),
      );
    } on RpcError {
      rethrow;
    } on GrpcError catch (error) {
      throw _rpcErrorFromGrpc(error);
    } catch (error) {
      throw RpcError.unavailable(
        debugMessage: 'Sui gRPC service info failed: ${error.runtimeType}',
      );
    } finally {
      await client.shutdown();
    }
  }
}

({String host, int port}) _parseGrpcEndpoint(String rpcUrl) {
  final uri = Uri.tryParse(rpcUrl);
  if (uri == null ||
      !uri.hasAuthority ||
      uri.scheme != 'https' ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw const RpcError.invalidUrl();
  }
  return (host: uri.host, port: uri.hasPort ? uri.port : 443);
}

RpcError _rpcErrorFromGrpc(GrpcError error) {
  return switch (error.code) {
    StatusCode.unauthenticated ||
    StatusCode.permissionDenied => const RpcError.invalidCredential(),
    StatusCode.resourceExhausted => const RpcError.rateLimited(),
    _ => RpcError.unavailable(
      debugMessage: 'Sui gRPC request failed with code ${error.code}',
    ),
  };
}
