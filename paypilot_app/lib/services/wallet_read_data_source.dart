// SPDX-License-Identifier: Apache-2.0

import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';
import 'package:http/http.dart' as http;

/// Implementation of [EmbeddedWalletReadDataSource] for the PayPilot Flutter app.
///
/// Connects to the BMONI Embedded API directly or through PayPilot's backend proxy.
/// Defaults to the Sandbox / Development environment and the shared test API key:
/// - Base URL: https://embedded-dev.bmoni.com
/// - Shared Key: pk_a025cacbf33a_76fb864113f3540909de5b1da39cc146906e35b1c6d4d1e4
class PayPilotWalletReadDataSource implements EmbeddedWalletReadDataSource {
  PayPilotWalletReadDataSource({
    http.Client? client,
    String? baseUrl,
    String? apiKey,
    String? userId,
    bool isProxy = false,
  }) : _delegate = BmoniEmbeddedWalletRemoteDataSource(
          client: client,
          baseUrl: baseUrl ?? BmoniUrls.development,
          apiKey: apiKey ?? BmoniUrls.sandboxSharedApiKey,
          userId: userId,
          isProxy: isProxy,
        );

  final BmoniEmbeddedWalletRemoteDataSource _delegate;

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletListResponse>> fetchWallets() =>
      _delegate.fetchWallets();

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletDetailResponse>> fetchWalletDetail(
    String walletId,
  ) =>
      _delegate.fetchWalletDetail(walletId);

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletBalanceResponse>> fetchBalance(
    String walletId,
  ) =>
      _delegate.fetchBalance(walletId);

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletTransactionsResponse>> fetchTransactions(
    String walletId, {
    int? page,
    int? pageSize,
  }) =>
      _delegate.fetchTransactions(walletId, page: page, pageSize: pageSize);
}
