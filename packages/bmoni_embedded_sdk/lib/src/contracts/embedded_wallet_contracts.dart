// SPDX-License-Identifier: Apache-2.0

import 'package:dartz/dartz.dart';

import '../failures/embedded_failure.dart';
import '../models/embedded_wallet_models.dart';

/// Network-facing contract for reading embedded wallets, balances, and transactions.
///
/// Implemented against the BMONI Embedded REST API or an application proxy backend.
abstract class EmbeddedWalletReadDataSource {
  Future<Either<EmbeddedFailure, EmbeddedWalletListResponse>> fetchWallets();

  Future<Either<EmbeddedFailure, EmbeddedWalletDetailResponse>> fetchWalletDetail(
    String walletId,
  );

  Future<Either<EmbeddedFailure, EmbeddedWalletBalanceResponse>> fetchBalance(
    String walletId,
  );

  Future<Either<EmbeddedFailure, EmbeddedWalletTransactionsResponse>> fetchTransactions(
    String walletId, {
    int? page,
    int? pageSize,
  });
}

/// Local persistence contract for embedded wallet lists and transaction histories.
abstract class EmbeddedWalletStorage {
  Future<void> saveWallets(List<EmbeddedWallet> wallets);
  Future<List<EmbeddedWallet>?> loadWallets();

  Future<void> saveTransactions(
    String walletId,
    List<EmbeddedWalletTransaction> transactions,
  );
  Future<List<EmbeddedWalletTransaction>?> loadTransactions(String walletId);
}

/// Cache contract for instant balance retrieval and offline fallback.
abstract class EmbeddedWalletBalanceCache {
  Future<void> saveBalance(String walletId, double balance);
  Future<double?> loadBalance(String walletId);
  Future<void> clearAll();
}

/// Standard cache key constants.
class EmbeddedWalletCacheKeys {
  const EmbeddedWalletCacheKeys._();

  static const String walletList = 'embedded_wallet_list';
  static const String transactionPrefix = 'embedded_txns_';
}

/// In-memory implementation of [EmbeddedWalletStorage] for tests and prototyping.
class InMemoryEmbeddedWalletStorage implements EmbeddedWalletStorage {
  final Map<String, List<EmbeddedWallet>> _wallets = {};
  final Map<String, List<EmbeddedWalletTransaction>> _txs = {};

  @override
  Future<void> saveWallets(List<EmbeddedWallet> wallets) async =>
      _wallets['wallets'] = List.unmodifiable(wallets);

  @override
  Future<List<EmbeddedWallet>?> loadWallets() async => _wallets['wallets'];

  @override
  Future<void> saveTransactions(
    String walletId,
    List<EmbeddedWalletTransaction> transactions,
  ) async => _txs[walletId] = List.unmodifiable(transactions);

  @override
  Future<List<EmbeddedWalletTransaction>?> loadTransactions(String walletId) async =>
      _txs[walletId];
}

/// In-memory implementation of [EmbeddedWalletBalanceCache] for fast lookup.
class InMemoryEmbeddedWalletBalanceCache implements EmbeddedWalletBalanceCache {
  final Map<String, double> _balances = {};

  @override
  Future<void> saveBalance(String walletId, double balance) async {
    _balances[walletId] = balance;
  }

  @override
  Future<double?> loadBalance(String walletId) async => _balances[walletId];

  @override
  Future<void> clearAll() async => _balances.clear();
}
