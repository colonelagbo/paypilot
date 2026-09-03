import 'wallet_service_stub.dart'
  if (dart.library.js_util) 'wallet_service_web.dart'
  if (dart.library.io) 'wallet_service_native.dart';

class WalletService {
  static void init() {}
  static Future<String> connect() => WalletPlatform.connect();
  static Future<String> signMessage(String message) => WalletPlatform.signMessage(message);
  static Future<String> signDigest(String hashHex) => WalletPlatform.signDigest(hashHex);
}
