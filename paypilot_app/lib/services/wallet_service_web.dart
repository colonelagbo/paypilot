import 'dart:js_util' as js_util;
import 'dart:async';

class WalletPlatform {
  static dynamic get _ethereum => js_util.getProperty(js_util.globalThis, 'ethereum');

  static Future<dynamic> _request(String method, [dynamic params]) async {
    final eth = _ethereum;
    if (eth == null) throw Exception('No browser wallet detected. Install/connect an EVM wallet such as MetaMask.');
    final result = js_util.callMethod(eth, 'request', [js_util.jsify({'method': method, if (params != null) 'params': params})]);
    return js_util.promiseToFuture(result);
  }

  static Future<String> connect() async {
    final accounts = await _request('eth_requestAccounts');
    final list = js_util.dartify(accounts);
    if (list is! List || list.isEmpty) throw Exception('No browser wallet account was selected.');
    return list.first.toString();
  }

  static Future<String> signMessage(String message) async {
    final address = await connect();
    final result = await _request('personal_sign', [message, address]);
    return result.toString();
  }

  // BMONI proposal signing is a raw digest signature, not EIP-191.
  static Future<String> signDigest(String hashHex) async {
    final address = await connect();
    final result = await _request('eth_sign', [address, hashHex]);
    return result.toString();
  }
}
