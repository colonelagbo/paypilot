import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';
import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk_platform_interface.dart';

class FallbackBmoniPlatform extends BmoniEmbeddedSdkPlatform {
  String? _cachedAddress;

  String _generateEthAddress() {
    final rand = Random();
    final bytes = List<int>.generate(20, (_) => rand.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '0x$hex';
  }

  @override
  Future<String> initWallet() async {
    _cachedAddress ??= _generateEthAddress();
    return _cachedAddress!;
  }

  @override
  Future<String> signMessage(String message) async {
    // 65-byte mock EIP-191 signature format (0x + 130 hex chars)
    final rand = Random();
    final r = List.generate(32, (_) => rand.nextInt(256)).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final s = List.generate(32, (_) => rand.nextInt(256)).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '0x$r${s}1b';
  }

  @override
  Future<String> signTransactionHash(String hashHex) async {
    // 65-byte raw secp256k1 signature format (0x + 130 hex chars)
    final rand = Random();
    final r = List.generate(32, (_) => rand.nextInt(256)).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final s = List.generate(32, (_) => rand.nextInt(256)).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '0x$r${s}1b';
  }

  @override
  Future<void> deleteWallet() async {
    _cachedAddress = null;
  }
}

class WalletService {
  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    _initialized = true;

    // If running on web or desktop without native Android/iOS channel, inject fallback
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS) {
      BmoniEmbeddedSdkPlatform.instance = FallbackBmoniPlatform();
    }

    BmoniEmbeddedSdk.initialize(pinLength: 6, requirePin: false);
  }

  static Future<String> getOrInitWallet() async {
    init();
    try {
      final has = await BmoniEmbeddedSdk.hasWallet();
      if (has) {
        final existing = await BmoniEmbeddedSdk.walletAddress();
        if (existing != null) return existing;
      }
      return await BmoniEmbeddedSdk.initWallet();
    } catch (e) {
      debugPrint('[WalletService] initWallet exception: $e');
      // Fallback
      return await BmoniEmbeddedSdk.initWallet();
    }
  }

  static Future<String?> getAddress() async {
    init();
    return await BmoniEmbeddedSdk.walletAddress();
  }

  static Future<String> signMessage(String message) async {
    init();
    return await BmoniEmbeddedSdk.signMessage(message);
  }

  static Future<String> signTransactionHash(String hashHex) async {
    init();
    return await BmoniEmbeddedSdk.signTransactionHash(hashHex);
  }
}
