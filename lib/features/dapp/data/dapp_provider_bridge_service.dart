import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/dapp_request_controller.dart';

final dappProviderBridgeServiceProvider = Provider<DappProviderBridgeService>(
  (ref) => DappProviderBridgeService(),
);

final class DappProviderBridgeService {
  DappProviderBridgeService() : _secureSession = false;

  DappProviderBridgeService._secure() : _secureSession = true;

  final bool _secureSession;
  final Map<String, String> _bridgeProofs = <String, String>{};

  DappProviderBridgeService createSession() {
    return DappProviderBridgeService._secure();
  }

  static const maxMessageLength = 256 * 1024;
  static const maxJsonDepth = 32;
  static const maxJsonNodes = 10000;

  String providerScript({
    String channelName = 'SafeWalletBridge',
    String? initialChainId,
    String? pageOrigin,
  }) {
    final bridgeProof = _secureSession
        ? _bridgeProofForOrigin(pageOrigin)
        : null;
    final encodedInitialChainId = initialChainId == null
        ? 'null'
        : jsonEncode(initialChainId);
    return '''
(function() {
  if (window.top !== window.self) {
    return;
  }
${bridgeProof == null ? '' : '  window.__safeWalletBridgeProof = ${jsonEncode(bridgeProof)};'}
  function safeLog(level, message, details) {
    try {
      var consoleObject = window.console;
      if (!consoleObject) {
        return;
      }
      var logger = consoleObject[level] || consoleObject.log;
      if (typeof logger !== 'function') {
        return;
      }
      if (details === undefined) {
        logger.call(consoleObject, message);
      } else {
        logger.call(consoleObject, message, details);
      }
    } catch (_) {}
  }
  function debugLog(message, details) {
    safeLog('debug', message, details);
  }
  function errorLog(message, details) {
    safeLog('error', message, details);
  }
  if (window.ethereum && window.ethereum.isSafeWalletDappProvider &&
      window.solana && window.solana.isSafeWalletDappProvider &&
      typeof window.__safeWalletRegisterStandardSolanaWallet === 'function' &&
      typeof window.__safeWalletRegisterStandardSuiWallet === 'function') {
    debugLog('[SafeWalletDapp] provider already installed', {
      chainId: window.ethereum && window.ethereum.chainId || null,
      hasEthereum: !!window.ethereum,
      hasSolana: !!window.solana,
      origin: window.location && window.location.origin || null
    });
    window.__safeWalletRegisterStandardSolanaWallet();
    window.__safeWalletRegisterStandardSuiWallet();
    return;
  }
  var callbacks = {};
  var listeners = {};
  var solanaListeners = {};
  var standardSolanaListeners = {};
  var standardSuiListeners = {};
  var nextId = 1;
  function emit(event, payload) {
    var handlers = listeners[event] ? listeners[event].slice() : [];
    handlers.forEach(function(handler) {
      try {
        handler(payload);
      } catch (_) {}
    });
  }
  function addListener(event, handler) {
    if (typeof handler !== 'function') {
      return window.ethereum;
    }
    if (!listeners[event]) {
      listeners[event] = [];
    }
    listeners[event].push(handler);
    return window.ethereum;
  }
  function removeListener(event, handler) {
    var handlers = listeners[event];
    if (!handlers) {
      return window.ethereum;
    }
    var index = handlers.indexOf(handler);
    if (index >= 0) {
      handlers.splice(index, 1);
    }
    return window.ethereum;
  }
  function removeAllListeners(event) {
    if (event) {
      delete listeners[event];
    } else {
      listeners = {};
    }
    return window.ethereum;
  }
  function emitSolana(event, payload) {
    var handlers = solanaListeners[event] ? solanaListeners[event].slice() : [];
    handlers.forEach(function(handler) {
      try {
        handler(payload);
      } catch (_) {}
    });
  }
  function addSolanaListener(event, handler) {
    if (typeof handler !== 'function') {
      return window.solana;
    }
    if (!solanaListeners[event]) {
      solanaListeners[event] = [];
    }
    solanaListeners[event].push(handler);
    return window.solana;
  }
  function removeSolanaListener(event, handler) {
    var handlers = solanaListeners[event];
    if (!handlers) {
      return window.solana;
    }
    var index = handlers.indexOf(handler);
    if (index >= 0) {
      handlers.splice(index, 1);
    }
    return window.solana;
  }
  function makeSolanaPublicKey(value) {
    if (!value) {
      return null;
    }
    return {
      toString: function() {
        return value;
      },
      toBase58: function() {
        return value;
      },
      toJSON: function() {
        return value;
      },
      equals: function(other) {
        if (!other) {
          return false;
        }
        if (typeof other === 'string') {
          return other === value;
        }
        if (typeof other.toBase58 === 'function') {
          return other.toBase58() === value;
        }
        if (typeof other.toString === 'function') {
          return other.toString() === value;
        }
        return false;
      }
    };
  }
  function solanaMessageBytes(message) {
    if (message == null) {
      return [];
    }
    if (message instanceof Uint8Array || Array.isArray(message)) {
      return Array.prototype.slice.call(message);
    }
    if (typeof message === 'string' && typeof TextEncoder !== 'undefined') {
      return Array.prototype.slice.call(new TextEncoder().encode(message));
    }
    return [];
  }
  function solanaTransactionBytes(transaction) {
    if (transaction == null) {
      return [];
    }
    if (transaction instanceof Uint8Array || Array.isArray(transaction)) {
      return Array.prototype.slice.call(transaction);
    }
    if (typeof transaction.serialize === 'function') {
      return Array.prototype.slice.call(transaction.serialize({
        requireAllSignatures: false,
        verifySignatures: false
      }));
    }
    return [];
  }
  function restoreSolanaTransaction(bytes, originalTransaction) {
    var serialized = new Uint8Array(bytes || []);
    var constructor = originalTransaction && originalTransaction.constructor;
    if (constructor && typeof constructor.deserialize === 'function') {
      return constructor.deserialize(serialized);
    }
    if (constructor && typeof constructor.from === 'function') {
      return constructor.from(serialized);
    }
    return serialized;
  }
  function solanaBase58ToBytes(value) {
    if (!value || typeof value !== 'string') {
      return new Uint8Array([]);
    }
    var alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    var bytes = [0];
    for (var i = 0; i < value.length; i++) {
      var carry = alphabet.indexOf(value[i]);
      if (carry < 0) {
        return new Uint8Array([]);
      }
      for (var j = 0; j < bytes.length; j++) {
        carry += bytes[j] * 58;
        bytes[j] = carry & 0xff;
        carry >>= 8;
      }
      while (carry > 0) {
        bytes.push(carry & 0xff);
        carry >>= 8;
      }
    }
    for (var k = 0; k < value.length && value[k] === '1'; k++) {
      bytes.push(0);
    }
    return new Uint8Array(bytes.reverse());
  }
  function emitStandardSolanaChange(properties) {
    var handlers = standardSolanaListeners.change
        ? standardSolanaListeners.change.slice()
        : [];
    handlers.forEach(function(handler) {
      try {
        handler(properties);
      } catch (_) {}
    });
  }
  function emitStandardSuiChange(properties) {
    var handlers = standardSuiListeners.change
        ? standardSuiListeners.change.slice()
        : [];
    handlers.forEach(function(handler) {
      try {
        handler(properties);
      } catch (_) {}
    });
  }
  function suiMessageBytes(message) {
    if (message == null) {
      return [];
    }
    if (message instanceof Uint8Array || Array.isArray(message)) {
      return Array.prototype.slice.call(message);
    }
    if (typeof message === 'string' && typeof TextEncoder !== 'undefined') {
      return Array.prototype.slice.call(new TextEncoder().encode(message));
    }
    return [];
  }
  function suiTransactionBytes(transaction) {
    if (transaction == null) {
      return Promise.resolve([]);
    }
    if (transaction instanceof Uint8Array || Array.isArray(transaction)) {
      return Promise.resolve(Array.prototype.slice.call(transaction));
    }
    var serialized;
    try {
      if (typeof transaction.build === 'function') {
        serialized = transaction.build();
      } else if (typeof transaction.toBytes === 'function') {
        serialized = transaction.toBytes();
      } else if (typeof transaction.serialize === 'function') {
        serialized = transaction.serialize();
      }
    } catch (error) {
      return Promise.reject(error);
    }
    return Promise.resolve(serialized).then(function(bytes) {
      return Array.prototype.slice.call(bytes || []);
    });
  }
  function normalizeParams(params) {
    if (params == null) {
      return [];
    }
    return Array.isArray(params) ? params : [params];
  }
  function sendRequest(args) {
    var id = nextId++;
    var payload = {
      id: id,
      origin: window.location.origin,
      bridgeProof: window.__safeWalletBridgeProof || null,
      method: args && args.method,
      params: normalizeParams(args && args.params)
    };
    return new Promise(function(resolve, reject) {
      callbacks[id] = {
        resolve: resolve,
        reject: reject,
        method: payload.method
      };
      debugLog('[SafeWalletDapp] request', {
        id: id,
        method: payload.method || null,
        origin: payload.origin,
        paramsCount: payload.params.length
      });
      try {
        $channelName.postMessage(JSON.stringify(payload));
      } catch (error) {
        delete callbacks[id];
        errorLog('[SafeWalletDapp] request postMessage error', {
          id: id,
          method: payload.method || null,
          message: error && error.message || String(error)
        });
        reject(error);
      }
    });
  }
  function send(methodOrPayload, paramsOrCallback) {
    if (typeof paramsOrCallback === 'function') {
      return sendAsync(methodOrPayload, paramsOrCallback);
    }
    if (typeof methodOrPayload === 'string') {
      return sendRequest({ method: methodOrPayload, params: paramsOrCallback });
    }
    return sendRequest(methodOrPayload);
  }
  function sendAsync(payload, callback) {
    var request = typeof payload === 'string'
        ? { method: payload, params: [] }
        : payload;
    sendRequest(request).then(function(result) {
      if (typeof callback === 'function') {
        callback(null, {
          jsonrpc: '2.0',
          id: request && request.id,
          result: result
        });
      }
    }).catch(function(error) {
      if (typeof callback === 'function') {
        callback(error, {
          jsonrpc: '2.0',
          id: request && request.id,
          error: error
        });
      }
    });
  }
  window.__safeWalletEmit = emit;
  window.__safeWalletEmitSolana = emitSolana;
  window.__safeWalletMakeSolanaPublicKey = makeSolanaPublicKey;
  window.__safeWalletResolve = function(response) {
    var responseId = response && response.id;
    var callback = callbacks[responseId];
    if (!callback) {
      errorLog('[SafeWalletDapp] resolve missing callback', {
        id: responseId == null ? null : responseId
      });
      return;
    }
    delete callbacks[responseId];
    if (response.error) {
      errorLog('[SafeWalletDapp] resolve error', {
        id: responseId,
        method: callback.method || null,
        code: response.error && response.error.code || null,
        message: response.error && response.error.message || null
      });
      callback.reject(response.error);
      return;
    }
    debugLog('[SafeWalletDapp] resolve result', {
      id: responseId,
      method: callback.method || null,
      resultType: response.result == null
          ? String(response.result)
          : Array.isArray(response.result) ? 'array' : typeof response.result
    });
    callback.resolve(response.result);
  };
  var provider = {
    isSafeWalletDappProvider: true,
    isMetaMask: true,
    _metamask: {
      isUnlocked: function() {
        return Promise.resolve(true);
      }
    },
    selectedAddress: null,
    chainId: $encodedInitialChainId,
    request: function(args) {
      return sendRequest(args);
    },
    enable: function() {
      return sendRequest({ method: 'eth_requestAccounts', params: [] });
    },
    send: function(methodOrPayload, paramsOrCallback) {
      return send(methodOrPayload, paramsOrCallback);
    },
    sendAsync: function(payload, callback) {
      return sendAsync(payload, callback);
    },
    isConnected: function() {
      return true;
    },
    on: function(event, handler) {
      return addListener(event, handler);
    },
    addListener: function(event, handler) {
      return addListener(event, handler);
    },
    removeListener: function(event, handler) {
      return removeListener(event, handler);
    },
    removeAllListeners: function(event) {
      return removeAllListeners(event);
    }
  };
  var solanaProvider = {
    isSafeWalletDappProvider: true,
    isPhantom: true,
    publicKey: null,
    isConnected: false,
    connect: function(options) {
      return sendRequest({ method: 'solana_connect', params: [options || {}] });
    },
    disconnect: function() {
      return sendRequest({ method: 'solana_disconnect', params: [] });
    },
    signMessage: function(message, encoding) {
      return sendRequest({
        method: 'solana_signMessage',
        params: [solanaMessageBytes(message), encoding]
      });
    },
    signTransaction: function(transaction) {
      return sendRequest({
        method: 'solana_signTransaction',
        params: [solanaTransactionBytes(transaction)]
      }).then(function(result) {
        return restoreSolanaTransaction(
          result && result.serializedTransaction,
          transaction
        );
      });
    },
    signAllTransactions: function(transactions) {
      var items = Array.isArray(transactions) ? transactions : [];
      return sendRequest({
        method: 'solana_signAllTransactions',
        params: [items.map(solanaTransactionBytes)]
      }).then(function(result) {
        var signed = result && result.serializedTransactions;
        if (!Array.isArray(signed)) {
          return [];
        }
        return signed.map(function(bytes, index) {
          return restoreSolanaTransaction(bytes, items[index]);
        });
      });
    },
    signAndSendTransaction: function(transaction, options) {
      return sendRequest({
        method: 'solana_signAndSendTransaction',
        params: [solanaTransactionBytes(transaction), options || {}]
      });
    },
    request: function(args) {
      var method = args && args.method;
      var params = normalizeParams(args && args.params);
      if (method === 'connect') {
        return solanaProvider.connect(params[0]);
      }
      if (method === 'disconnect') {
        return solanaProvider.disconnect();
      }
      if (method === 'signMessage') {
        return solanaProvider.signMessage(params[0], params[1]);
      }
      if (method === 'signTransaction') {
        return solanaProvider.signTransaction(params[0]);
      }
      if (method === 'signAllTransactions') {
        return solanaProvider.signAllTransactions(params[0]);
      }
      if (method === 'signAndSendTransaction') {
        return solanaProvider.signAndSendTransaction(params[0], params[1]);
      }
      return Promise.reject({ code: 4200, message: 'unsupported_solana_method' });
    },
    on: function(event, handler) {
      return addSolanaListener(event, handler);
    },
    addListener: function(event, handler) {
      return addSolanaListener(event, handler);
    },
    removeListener: function(event, handler) {
      return removeSolanaListener(event, handler);
    }
  };
  provider.providers = [provider];
  var providerInfo = {
    uuid: '350670db-19fa-4704-a166-e52e178b59d2',
    name: 'SafeWallet',
    icon: 'data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPHN2ZyB3aWR0aD0iMTAyNHB4IiBoZWlnaHQ9IjEwMjRweCIgdmlld0JveD0iMCAwIDEwMjQgMTAyNCIgdmVyc2lvbj0iMS4xIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIj4KICAgIDx0aXRsZT53YWxsZXRfbG9nbzwvdGl0bGU+CiAgICA8ZGVmcz4KICAgICAgICA8cGF0aCBkPSJNMTgwLDAgTDg0NCwwIEM5NDMuNDExMjU1LDAgMTAyNCw4MC41ODg3NDUgMTAyNCwxODAgTDEwMjQsODQ0IEMxMDI0LDk0My40MTEyNTUgOTQzLjQxMTI1NSwxMDI0IDg0NCwxMDI0IEwxODAsMTAyNCBDODAuNTg4NzQ1LDEwMjQgMCw5NDMuNDExMjU1IDAsODQ0IEwwLDE4MCBDMCw4MC41ODg3NDUgODAuNTg4NzQ1LDAgMTgwLDAgWiIgaWQ9InBhdGgtMSI+PC9wYXRoPgogICAgPC9kZWZzPgogICAgPGcgaWQ9IndhbGxldF9sb2dvIiBzdHJva2U9Im5vbmUiIGZpbGw9Im5vbmUiIHhsaW5rOmhyZWY9IiNwYXRoLTEiIGZpbGwtcnVsZT0iZXZlbm9kZCI+CiAgICAgICAgPHVzZSBmaWxsPSIjRkZGRkZGIiB4bGluazpocmVmPSIjcGF0aC0xIj48L3VzZT4KICAgICAgICA8ZyBpZD0i57yW57uEIiBzdHJva2Utd2lkdGg9IjEiIHRyYW5zZm9ybT0idHJhbnNsYXRlKDE5NSwgMjc3KSI+CiAgICAgICAgICAgIDxnPgogICAgICAgICAgICAgICAgPHBhdGggZD0iTTAsNjkgTDU1MCw2OSBDNTc3LjYxNDIzNyw2OSA2MDAsOTEuMzg1NzYyNSA2MDAsMTE5IEw2MDAsNDE5IEM2MDAsNDQ2LjYxNDIzNyA1NzcuNjE0MjM3LDQ2OSA1NTAsNDY5IEw1MCw0NjkgQzIyLjM4NTc2MjUsNDY5IDAsNDQ2LjYxNDIzNyAwLDQxOSBMMCw2OSBaIiBpZD0i55+p5b2iIiBmaWxsPSIjMUEzMDU0Ij48L3BhdGg+CiAgICAgICAgICAgICAgICA8cGF0aCBkPSJNNTQzLDUwIEw1NDMsNjQgTC01LDY0IEwtNSw1MCBDLTUsMTkuNjI0MzM4OCAxOS42MjQzMzg4LC01IDUwLC01IEw0ODgsLTUgQzUxOC4zNzU2NjEsLTUgNTQzLDE5LjYyNDMzODggNTQzLDUwIFoiIGlkPSLnn6nlvaItNCIgc3Ryb2tlPSIjRkZGRkZGIiBzdHJva2Utd2lkdGg9IjEwIiBmaWxsPSIjMUEzMDU0Ij48L3BhdGg+CiAgICAgICAgICAgICAgICA8cmVjdCBpZD0i55+p5b2iLTUiIGZpbGw9IiMxQTMwNTQiIHg9IjAiIHk9IjQ0IiB3aWR0aD0iNTUiIGhlaWdodD0iNjMiPjwvcmVjdD4KICAgICAgICAgICAgICAgIDxjaXJjbGUgaWQ9IuakreWchuW9oiIgZmlsbD0iI0ZGRkZGRiIgY3g9IjU0LjY1MzU0NDIiIGN5PSI2My41OTY4NTE0IiByPSI0Ljk2ODUwNDAyIj48L2NpcmNsZT4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSg0MDMsIDEzOSkiPgogICAgICAgICAgICAgICAgPHBhdGggZD0iTTIzNiwxOTUgTDgwLDE5NSBDMzMuMDU1Nzk2MywxOTUgLTUsMTU2Ljk0NDIwNCAtNSwxMTAgTC01LDEwNiBDLTUsNTkuMDU1Nzk2MyAzMy4wNTU3OTYzLDIxIDgwLDIxIEwyMzYsMjEgWiIgaWQ9IuefqeW9oi0yIiBzdHJva2U9IiNGRkZGRkYiIHN0cm9rZS13aWR0aD0iMTAiIGZpbGw9IiMxQTMwNTQiPjwvcGF0aD4KICAgICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yMTEsMCBDMjIyLjA0NTY5NSwwIDIzMSw4Ljk1NDMwNSAyMzEsMjAgTDIzMSw0NSBMMjExLDQ1IEwyMTEsMCBaIiBpZD0i55+p5b2iLTMiIGZpbGw9IiMxQTMwNTQiPjwvcGF0aD4KICAgICAgICAgICAgICAgIDxnIGlkPSJMT0NLIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSg0MSwgMzMpIiBmaWxsPSIjRkZGRkZGIj4KICAgICAgICAgICAgICAgICAgICA8ZyBpZD0i57yW57uEIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSgzMS44NzUsIDIzLjQzNzUpIj4KICAgICAgICAgICAgICAgICAgICAgICAgPHBhdGggZD0iTTc3LjgxMjUsMTAzLjEyNSBMOC40Mzc1LDEwMy4xMjUgQzMuNzUsMTAzLjEyNSAwLDk5LjM3NSAwLDk0LjY4NzUgTDAsNTEuNTYyNSBDMCw0Ni44NzUgNC42ODc1LDQzLjEyNSA4LjQzNzUsNDMuMTI1IEw3Ni44NzUsNDMuMTI1IEM4Mi41LDQzLjEyNSA4NS4zMTI1LDQ2Ljg3NSA4NS4zMTI1LDUxLjU2MjUgTDg1LjMxMjUsOTQuNjg3NSBDODYuMjUsOTkuMzc1IDgyLjUsMTAzLjEyNSA3Ny44MTI1LDEwMy4xMjUgWiIgaWQ9Iui3r+W+hCI+PC9wYXRoPgogICAgICAgICAgICAgICAgICAgICAgICA8cGF0aCBkPSJNMjEuNTYyNSwzOC40Mzc1IEwyMS41NjI1LDI2LjI1IEMyMS41NjI1LDE1LjkzNzUgMjkuMDYyNSw4LjQzNzUgMzkuMzc1LDguNDM3NSBMNDYuODc1LDguNDM3NSBDNTYuMjUsOC40Mzc1IDY0LjY4NzUsMTUuOTM3NSA2NC42ODc1LDI2LjI1IEw2NC42ODc1LDM4LjQzNzUgTDczLjEyNSwzOC40Mzc1IEw3My4xMjUsMjYuMjUgQzczLjEyNSwxMS4yNSA2MC45Mzc1LDAgNDYuODc1LDAgTDM5LjM3NSwwIEMyNC4zNzUsMCAxMy4xMjUsMTIuMTg3NSAxMy4xMjUsMjYuMjUgTDEzLjEyNSwzOC40Mzc1IEwyMS41NjI1LDM4LjQzNzUgWiIgaWQ9Iui3r+W+hCI+PC9wYXRoPgogICAgICAgICAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgPC9nPgogICAgICAgIDwvZz4KICAgIDwvZz4KPC9zdmc+',
    rdns: 'com.safewallet.mobile'
  };
  providerInfo = Object.freeze(providerInfo);
  var standardSolanaAccounts = [];
  var standardSolanaAccountFeatures = Object.freeze([
    'solana:signMessage',
    'solana:signTransaction',
    'solana:signAndSendTransaction'
  ]);
  var standardSolanaFeatures = Object.freeze({
    'standard:connect': Object.freeze({
      version: '1.0.0',
      connect: function(input) {
        return solanaProvider.connect(input || {}).then(function() {
          return { accounts: standardSolanaAccounts.slice() };
        });
      }
    }),
    'standard:disconnect': Object.freeze({
      version: '1.0.0',
      disconnect: function() {
        return solanaProvider.disconnect().then(function() {});
      }
    }),
    'standard:events': Object.freeze({
      version: '1.0.0',
      on: function(event, listener) {
        if (event !== 'change' || typeof listener !== 'function') {
          return function() {};
        }
        if (!standardSolanaListeners.change) {
          standardSolanaListeners.change = [];
        }
        standardSolanaListeners.change.push(listener);
        return function() {
          var handlers = standardSolanaListeners.change || [];
          var index = handlers.indexOf(listener);
          if (index >= 0) {
            handlers.splice(index, 1);
          }
        };
      }
    }),
    'solana:signMessage': Object.freeze({
      version: '1.1.0',
      signMessage: function() {
        var inputs = Array.prototype.slice.call(arguments);
        return Promise.all(inputs.map(function(input) {
          var message = input && input.message ? input.message : [];
          return solanaProvider.signMessage(message).then(function(result) {
            return {
              signedMessage: new Uint8Array(message || []),
              signature: result && result.signature instanceof Uint8Array
                  ? result.signature
                  : new Uint8Array(result && result.signature || []),
              signatureType: 'ed25519'
            };
          });
        }));
      }
    }),
    'solana:signTransaction': Object.freeze({
      version: '1.0.0',
      supportedTransactionVersions: Object.freeze(['legacy', 0]),
      signTransaction: function() {
        var inputs = Array.prototype.slice.call(arguments);
        return sendRequest({
          method: 'solana_signAllTransactions',
          params: [inputs.map(function(input) {
            return Array.prototype.slice.call(input && input.transaction || []);
          })]
        }).then(function(result) {
          var transactions = result && result.serializedTransactions;
          if (!Array.isArray(transactions)) {
            return [];
          }
          return transactions.map(function(bytes) {
            return { signedTransaction: new Uint8Array(bytes || []) };
          });
        });
      }
    }),
    'solana:signAndSendTransaction': Object.freeze({
      version: '1.0.0',
      supportedTransactionVersions: Object.freeze(['legacy', 0]),
      signAndSendTransaction: function() {
        var inputs = Array.prototype.slice.call(arguments);
        return Promise.all(inputs.map(function(input) {
          return sendRequest({
            method: 'solana_signAndSendTransaction',
            params: [
              Array.prototype.slice.call(input && input.transaction || []),
              input && input.options || {}
            ]
          }).then(function(result) {
            return {
              signature: solanaBase58ToBytes(result && result.signature)
            };
          });
        }));
      }
    })
  });
  function makeStandardSolanaAccount(address) {
    var publicKey = solanaBase58ToBytes(address);
    return Object.freeze({
      get address() {
        return address;
      },
      get publicKey() {
        return publicKey.slice();
      },
      get chains() {
        return standardSolanaWallet.chains.slice();
      },
      get features() {
        return standardSolanaAccountFeatures.slice();
      },
      get label() {
        return providerInfo.name;
      },
      get icon() {
        return providerInfo.icon;
      }
    });
  }
  function setStandardSolanaAccount(address) {
    standardSolanaAccounts = address ? [makeStandardSolanaAccount(address)] : [];
    emitStandardSolanaChange({ accounts: standardSolanaAccounts.slice() });
  }
  var standardSolanaWallet = {
    version: '1.0.0',
    name: providerInfo.name,
    icon: providerInfo.icon,
    chains: ['solana:mainnet'],
    features: standardSolanaFeatures,
    get accounts() {
      return standardSolanaAccounts.slice();
    }
  };
  Object.freeze(standardSolanaWallet.chains);
  Object.freeze(standardSolanaWallet);
  var standardSuiAccounts = [];
  var standardSuiAccountFeatures = Object.freeze([
    'sui:signPersonalMessage',
    'sui:signTransaction',
    'sui:signAndExecuteTransaction'
  ]);
  var standardSuiFeatures = Object.freeze({
    'standard:connect': Object.freeze({
      version: '1.0.0',
      connect: function(input) {
        return sendRequest({
          method: 'sui_connect',
          params: [input || {}]
        }).then(function() {
          return { accounts: standardSuiAccounts.slice() };
        });
      }
    }),
    'standard:disconnect': Object.freeze({
      version: '1.0.0',
      disconnect: function() {
        return sendRequest({
          method: 'sui_disconnect',
          params: []
        }).then(function() {});
      }
    }),
    'standard:events': Object.freeze({
      version: '1.0.0',
      on: function(event, listener) {
        if (event !== 'change' || typeof listener !== 'function') {
          return function() {};
        }
        if (!standardSuiListeners.change) {
          standardSuiListeners.change = [];
        }
        standardSuiListeners.change.push(listener);
        return function() {
          var handlers = standardSuiListeners.change || [];
          var index = handlers.indexOf(listener);
          if (index >= 0) {
            handlers.splice(index, 1);
          }
        };
      }
    }),
    'sui:signPersonalMessage': Object.freeze({
      version: '1.1.0',
      signPersonalMessage: function(input) {
        var account = input && input.account;
        return sendRequest({
          method: 'sui_signPersonalMessage',
          params: [{
            message: suiMessageBytes(input && input.message),
            account: account && account.address,
            chain: input && input.chain
          }]
        });
      }
    }),
    'sui:signTransaction': Object.freeze({
      version: '2.0.0',
      signTransaction: function(input) {
        var account = input && input.account;
        return suiTransactionBytes(input && input.transaction).then(
          function(bytes) {
            return sendRequest({
              method: 'sui_signTransaction',
              params: [{
                transaction: bytes,
                account: account && account.address,
                chain: input && input.chain
              }]
            });
          }
        );
      }
    }),
    'sui:signAndExecuteTransaction': Object.freeze({
      version: '2.0.0',
      signAndExecuteTransaction: function(input) {
        var account = input && input.account;
        return suiTransactionBytes(input && input.transaction).then(
          function(bytes) {
            return sendRequest({
              method: 'sui_signAndExecuteTransaction',
              params: [{
                transaction: bytes,
                account: account && account.address,
                chain: input && input.chain,
                options: input && input.options || {}
              }]
            });
          }
        );
      }
    })
  });
  function makeStandardSuiAccount(address, publicKey, chain) {
    return Object.freeze({
      address: address,
      publicKey: new Uint8Array(publicKey || []),
      chains: Object.freeze([chain]),
      features: standardSuiAccountFeatures,
      label: providerInfo.name,
      icon: providerInfo.icon
    });
  }
  function setStandardSuiAccount(address, publicKey, chain) {
    standardSuiAccounts = address && chain
        ? [makeStandardSuiAccount(address, publicKey, chain)]
        : [];
    emitStandardSuiChange({ accounts: standardSuiAccounts.slice() });
  }
  var standardSuiWallet = {
    version: '1.0.0',
    name: providerInfo.name,
    icon: providerInfo.icon,
    chains: ['sui:mainnet', 'sui:testnet', 'sui:devnet'],
    features: standardSuiFeatures,
    get accounts() {
      return standardSuiAccounts.slice();
    }
  };
  Object.freeze(standardSuiWallet.chains);
  Object.freeze(standardSuiWallet);
  var providerDetail = Object.freeze({
    info: providerInfo,
    provider: provider
  });
  function announceProvider() {
    if (typeof window.dispatchEvent !== 'function' ||
        typeof window.CustomEvent !== 'function') {
      return;
    }
    window.dispatchEvent(new CustomEvent('eip6963:announceProvider', {
      detail: providerDetail
    }));
  }
  function registerStandardSolanaWallet() {
    if (typeof window.dispatchEvent !== 'function' ||
        typeof window.CustomEvent !== 'function') {
      return;
    }
    var callback = function(api) {
      if (api && typeof api.register === 'function') {
        api.register(standardSolanaWallet);
      }
    };
    try {
      window.dispatchEvent(new CustomEvent('wallet-standard:register-wallet', {
        detail: callback
      }));
    } catch (_) {}
    try {
      window.addEventListener('wallet-standard:app-ready', function(event) {
        callback(event && event.detail);
      });
    } catch (_) {}
    try {
      if (window.navigator) {
        (window.navigator.wallets || (window.navigator.wallets = [])).push(
          function(api) {
            callback(api);
          }
        );
      }
    } catch (_) {}
  }
  function registerStandardSuiWallet() {
    if (typeof window.dispatchEvent !== 'function' ||
        typeof window.CustomEvent !== 'function') {
      return;
    }
    var callback = function(api) {
      if (api && typeof api.register === 'function') {
        api.register(standardSuiWallet);
      }
    };
    try {
      window.dispatchEvent(new CustomEvent('wallet-standard:register-wallet', {
        detail: callback
      }));
    } catch (_) {}
    try {
      if (!window.__safeWalletSuiAppReadyListenerInstalled) {
        window.__safeWalletSuiAppReadyListenerInstalled = true;
        window.addEventListener('wallet-standard:app-ready', function(event) {
          callback(event && event.detail);
        });
      }
    } catch (_) {}
    try {
      if (window.navigator &&
          !window.__safeWalletSuiNavigatorRegistrationInstalled) {
        window.__safeWalletSuiNavigatorRegistrationInstalled = true;
        (window.navigator.wallets || (window.navigator.wallets = [])).push(
          function(api) {
            callback(api);
          }
        );
      }
    } catch (_) {}
  }
  window.__safeWalletRegisterStandardSolanaWallet =
      registerStandardSolanaWallet;
  window.__safeWalletSetStandardSolanaAccount = setStandardSolanaAccount;
  window.__safeWalletRegisterStandardSuiWallet = registerStandardSuiWallet;
  window.__safeWalletSetStandardSuiAccount = setStandardSuiAccount;
  window.ethereum = provider;
  window.ethereum.providers = provider.providers;
  window.phantom = window.phantom || {};
  window.phantom.solana = solanaProvider;
  window.solana = solanaProvider;
  debugLog('[SafeWalletDapp] provider installed', {
    chainId: provider.chainId || null,
    hasEthereum: !!window.ethereum,
    hasSolana: !!window.solana,
    origin: window.location && window.location.origin || null
  });
  window.addEventListener('eip6963:requestProvider', announceProvider);
  registerStandardSolanaWallet();
  registerStandardSuiWallet();
  setTimeout(function() {
    if (provider.chainId && window.__safeWalletEmit) {
      window.__safeWalletEmit('connect', { chainId: provider.chainId });
    }
    announceProvider();
  }, 0);
  window.dispatchEvent(new Event('ethereum#initialized'));
  window.dispatchEvent(new Event('solana#initialized'));
})();
''';
  }

  DappRpcRequest? parseRequest({
    required String message,
    required String fallbackOrigin,
  }) {
    if (message.length > maxMessageLength) {
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(message);
    } on FormatException {
      return null;
    }
    if (decoded is! Map || !_isWithinJsonLimits(decoded)) {
      return null;
    }
    final json = decoded.cast<String, Object?>();
    final fallbackWebOrigin = _canonicalWebOrigin(fallbackOrigin);
    final claimedOrigin = json['origin'];
    if (fallbackWebOrigin == null ||
        claimedOrigin is! String ||
        _canonicalWebOrigin(claimedOrigin) != fallbackWebOrigin) {
      return null;
    }
    if (_secureSession) {
      final expectedProof = _bridgeProofs[fallbackWebOrigin];
      final claimedProof = json['bridgeProof'];
      if (expectedProof == null ||
          claimedProof is! String ||
          claimedProof != expectedProof) {
        return null;
      }
    }
    final method = json['method'];
    if (method is! String || method.isEmpty || method.length > 128) {
      return null;
    }
    final params = json['params'];
    return DappRpcRequest(
      id: json['id'],
      origin: fallbackWebOrigin,
      method: method,
      params: params is List ? params.cast<Object?>() : const [],
    );
  }

  String? _canonicalWebOrigin(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final defaultPort = scheme == 'https' ? 443 : 80;
    final port = uri.hasPort && uri.port != defaultPort ? ':${uri.port}' : '';
    return '$scheme://$host$port';
  }

  String _bridgeProofForOrigin(String? value) {
    final origin = value == null ? null : _canonicalWebOrigin(value);
    if (origin == null) {
      throw ArgumentError.value(value, 'pageOrigin', 'Invalid web origin');
    }
    return _bridgeProofs.putIfAbsent(origin, _newBridgeProof);
  }

  String _newBridgeProof() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  bool _isWithinJsonLimits(Object? root) {
    final pending = <({Object? value, int depth})>[(value: root, depth: 1)];
    var nodes = 0;
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      nodes += 1;
      if (nodes > maxJsonNodes || current.depth > maxJsonDepth) {
        return false;
      }
      final value = current.value;
      if (value is List) {
        for (final child in value) {
          pending.add((value: child, depth: current.depth + 1));
        }
      } else if (value is Map) {
        for (final child in value.values) {
          pending.add((value: child, depth: current.depth + 1));
        }
      }
    }
    return true;
  }

  String callbackScript({
    DappRpcRequest? request,
    Object? id,
    required DappRequestResult result,
  }) {
    final response = _response(request?.id ?? id, result);
    return '''
(function() {
  var response = ${jsonEncode(response)};
${_providerStateUpdateScript(request, result)}
  window.__safeWalletResolve(response);
})();
''';
  }

  String _providerStateUpdateScript(
    DappRpcRequest? request,
    DappRequestResult result,
  ) {
    if (!result.isSuccess || request == null) {
      return '';
    }
    return switch (request.method) {
      'eth_requestAccounts' => _accountsUpdateScript(emitChange: true),
      'wallet_requestPermissions' => _permissionsUpdateScript(),
      'eth_accounts' => _accountsUpdateScript(emitChange: false),
      'eth_chainId' =>
        '''
  if (window.ethereum && typeof response.result === 'string') {
    window.ethereum.chainId = response.result;
  }
''',
      'wallet_switchEthereumChain' => _chainSwitchUpdateScript(request),
      'solana_connect' => _solanaConnectUpdateScript(),
      'solana_disconnect' => _solanaDisconnectUpdateScript(),
      'solana_signMessage' => _solanaSignMessageUpdateScript(),
      'sui_connect' => _suiConnectUpdateScript(),
      'sui_disconnect' => _suiDisconnectUpdateScript(),
      _ => '',
    };
  }

  String _accountsUpdateScript({required bool emitChange}) {
    final emitScript = emitChange
        ? '''
    if (window.__safeWalletEmit) {
      window.__safeWalletEmit('accountsChanged', response.result);
    }
'''
        : '';
    return '''
  if (window.ethereum && Array.isArray(response.result)) {
    window.ethereum.selectedAddress =
        response.result.length > 0 ? response.result[0] : null;
$emitScript  }
''';
  }

  String _permissionsUpdateScript() {
    return '''
  if (window.ethereum && Array.isArray(response.result)) {
    var permissionAccounts = [];
    response.result.some(function(permission) {
      if (!permission || permission.parentCapability !== 'eth_accounts' ||
          !Array.isArray(permission.caveats)) {
        return false;
      }
      return permission.caveats.some(function(caveat) {
        if (caveat && caveat.type === 'restrictReturnedAccounts' &&
            Array.isArray(caveat.value)) {
          permissionAccounts = caveat.value;
          return true;
        }
        return false;
      });
    });
    window.ethereum.selectedAddress =
        permissionAccounts.length > 0 ? permissionAccounts[0] : null;
    if (window.__safeWalletEmit) {
      window.__safeWalletEmit('accountsChanged', permissionAccounts);
    }
  }
''';
  }

  String _chainSwitchUpdateScript(DappRpcRequest request) {
    final chainId = _chainIdFromSwitchParams(request.params);
    if (chainId == null) {
      return '';
    }
    final encodedChainId = jsonEncode(chainId);
    return '''
  if (window.ethereum) {
    window.ethereum.chainId = $encodedChainId;
    if (window.__safeWalletEmit) {
      window.__safeWalletEmit('chainChanged', $encodedChainId);
    }
  }
''';
  }

  String _solanaConnectUpdateScript() {
    return '''
  if (window.solana && response.result &&
      typeof response.result.publicKey === 'string') {
    var publicKey = response.result.publicKey;
    window.solana.publicKey =
        window.__safeWalletMakeSolanaPublicKey(publicKey);
    window.solana.isConnected = true;
    if (window.__safeWalletSetStandardSolanaAccount) {
      window.__safeWalletSetStandardSolanaAccount(publicKey);
    }
    response.result = { publicKey: window.solana.publicKey };
    if (window.__safeWalletEmitSolana) {
      window.__safeWalletEmitSolana('connect', window.solana.publicKey);
    }
  }
''';
  }

  String _solanaDisconnectUpdateScript() {
    return '''
  if (window.solana) {
    window.solana.publicKey = null;
    window.solana.isConnected = false;
    if (window.__safeWalletSetStandardSolanaAccount) {
      window.__safeWalletSetStandardSolanaAccount(null);
    }
    if (window.__safeWalletEmitSolana) {
      window.__safeWalletEmitSolana('disconnect');
    }
  }
''';
  }

  String _solanaSignMessageUpdateScript() {
    return '''
  if (window.solana && response.result &&
      Array.isArray(response.result.signature)) {
    response.result.signature = new Uint8Array(response.result.signature);
    if (typeof response.result.publicKey === 'string') {
      response.result.publicKey =
          window.__safeWalletMakeSolanaPublicKey(response.result.publicKey);
    }
  }
''';
  }

  String _suiConnectUpdateScript() {
    return '''
  if (response.result && typeof response.result.address === 'string' &&
      Array.isArray(response.result.publicKey) &&
      typeof response.result.chain === 'string' &&
      window.__safeWalletSetStandardSuiAccount) {
    response.result.publicKey = new Uint8Array(response.result.publicKey);
    window.__safeWalletSetStandardSuiAccount(
      response.result.address,
      response.result.publicKey,
      response.result.chain
    );
  }
''';
  }

  String _suiDisconnectUpdateScript() {
    return '''
  if (window.__safeWalletSetStandardSuiAccount) {
    window.__safeWalletSetStandardSuiAccount(null, null, null);
  }
''';
  }

  Map<String, Object?> _response(Object? id, DappRequestResult result) {
    if (result.isSuccess) {
      return {'jsonrpc': '2.0', 'id': id, 'result': result.value};
    }
    final jsonRpcError = result.jsonRpcError;
    if (jsonRpcError != null) {
      final error = <String, Object?>{
        'code': jsonRpcError.code,
        'message': jsonRpcError.message,
      };
      if (jsonRpcError.data != null) {
        error['data'] = jsonRpcError.data;
      }
      return {'jsonrpc': '2.0', 'id': id, 'error': error};
    }
    return {
      'jsonrpc': '2.0',
      'id': id,
      'error': {
        'code': _rpcErrorCode(result.status),
        'message': result.errorCode ?? 'dapp_request_failed',
      },
    };
  }

  int _rpcErrorCode(DappRequestResultStatus status) {
    return switch (status) {
      DappRequestResultStatus.rejected => 4001,
      DappRequestResultStatus.walletLocked ||
      DappRequestResultStatus.authorizationRequired => 4100,
      DappRequestResultStatus.unsupported => 4200,
      DappRequestResultStatus.confirmationRequired ||
      DappRequestResultStatus.failure ||
      DappRequestResultStatus.success => -32603,
    };
  }
}

String? _chainIdFromSwitchParams(List<Object?> params) {
  if (params.isEmpty) {
    return null;
  }
  final first = params.first;
  if (first is! Map) {
    return null;
  }
  final value = first['chainId'];
  if (value is! String || value.isEmpty) {
    return null;
  }
  if (value.startsWith('0x')) {
    return value;
  }
  final parsed = BigInt.tryParse(value);
  if (parsed == null) {
    return value;
  }
  return '0x${parsed.toRadixString(16)}';
}
