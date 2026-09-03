class WalletPlatform {
  static Future<String> connect() => throw UnsupportedError('No wallet platform available');
  static Future<String> signMessage(String message) => throw UnsupportedError('No wallet platform available');
  static Future<String> signDigest(String hashHex) => throw UnsupportedError('No wallet platform available');
}
