import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';

class WalletPlatform {
  static Future<String> connect() async {
    final has = await BmoniEmbeddedSdk.hasWallet();
    if (has) {
      final address = await BmoniEmbeddedSdk.walletAddress();
      if (address != null && address.isNotEmpty) return address;
    }
    return BmoniEmbeddedSdk.initWallet();
  }

  static Future<String> signMessage(String message) => BmoniEmbeddedSdk.signMessage(message);
  static Future<String> signDigest(String hashHex) => BmoniEmbeddedSdk.signTransactionHash(hashHex);
}
