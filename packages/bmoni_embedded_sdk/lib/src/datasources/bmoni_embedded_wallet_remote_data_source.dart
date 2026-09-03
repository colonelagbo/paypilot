// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;

import '../constants/bmoni_urls.dart';
import '../contracts/embedded_wallet_contracts.dart';
import '../failures/embedded_failure.dart';
import '../models/embedded_wallet_models.dart';

/// Concrete [EmbeddedWalletReadDataSource] implementation communicating directly with
/// the BMONI Embedded REST API or an application proxy server.
class BmoniEmbeddedWalletRemoteDataSource implements EmbeddedWalletReadDataSource {
  BmoniEmbeddedWalletRemoteDataSource({
    http.Client? client,
    this.baseUrl = BmoniUrls.development,
    this.apiKey = BmoniUrls.sandboxSharedApiKey,
    this.userId,
    this.customHeaders,
    this.isProxy = false,
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// Base URL for API requests. Defaults to [BmoniUrls.development].
  final String baseUrl;

  /// Partner API key sent in the `x-api-key` header.
  final String apiKey;

  /// Optional BMONI user ID for user-scoped REST paths (`/v1/users/{userId}/...`).
  final String? userId;

  /// Optional additional request headers.
  final Map<String, String>? customHeaders;

  /// When true, endpoints are formatted for standard proxy paths (`/wallets...`)
  /// rather than direct BMONI endpoints (`/v1/users/{userId}/smart-wallets/...`).
  final bool isProxy;

  Map<String, String> get _headers => {
    BmoniUrls.apiKeyHeader: apiKey,
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    ...?customHeaders,
  };

  Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$cleanBase$cleanPath');
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }
    return uri;
  }

  Future<Either<EmbeddedFailure, T>> _safeExecute<T>({
    required Uri uri,
    required T Function(dynamic json) parser,
  }) async {
    try {
      final response = await _client.get(uri, headers: _headers);

      final bodyText = response.body;
      dynamic decoded;
      try {
        decoded = bodyText.isNotEmpty ? jsonDecode(bodyText) : {};
      } catch (e) {
        decoded = bodyText;
      }

      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        try {
          return Right(parser(decoded));
        } catch (e) {
          return Left(
            EmbeddedValidationFailure(
              'Failed to parse response payload: $e',
              statusCode: statusCode,
              details: decoded,
            ),
          );
        }
      }

      final errorMessage = (decoded is Map ? (decoded['message'] ?? decoded['error']) : null)?.toString() ??
          'Request failed with HTTP $statusCode';

      switch (statusCode) {
        case 401:
          return Left(EmbeddedAuthenticationFailure(errorMessage, statusCode: 401, details: decoded));
        case 403:
          return Left(EmbeddedAuthorizationFailure(errorMessage, statusCode: 403, details: decoded));
        case 404:
          return Left(EmbeddedNotFoundFailure(errorMessage, statusCode: 404, details: decoded));
        case 429:
          return Left(EmbeddedRateLimitFailure(errorMessage, statusCode: 429, details: decoded));
        default:
          if (statusCode >= 500) {
            return Left(EmbeddedServerFailure(errorMessage, statusCode: statusCode, details: decoded));
          }
          return Left(EmbeddedValidationFailure(errorMessage, statusCode: statusCode, details: decoded));
      }
    } on SocketException catch (e) {
      return Left(EmbeddedNetworkFailure('Network connection error: ${e.message}', details: e));
    } on http.ClientException catch (e) {
      return Left(EmbeddedNetworkFailure('HTTP client error: ${e.message}', details: e));
    } on TimeoutException catch (e) {
      return Left(EmbeddedNetworkFailure('Request timed out: ${e.message}', details: e));
    } on FormatException catch (e) {
      return Left(EmbeddedValidationFailure('Malformed server response: ${e.message}', details: e));
    } catch (e) {
      return Left(EmbeddedServerFailure('Unexpected error occurred: $e', details: e));
    }
  }

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletListResponse>> fetchWallets() {
    final String path;
    if (isProxy) {
      path = '/wallets';
    } else if (userId != null && userId!.isNotEmpty) {
      path = '/v1/users/$userId/smart-wallets/account/wallets';
    } else {
      path = '/v1/smart-wallets';
    }

    return _safeExecute(
      uri: _buildUri(path),
      parser: (json) => EmbeddedWalletListResponse.fromJson(json),
    );
  }

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletDetailResponse>> fetchWalletDetail(String walletId) {
    final String path;
    if (isProxy) {
      path = '/wallets/$walletId';
    } else if (userId != null && userId!.isNotEmpty) {
      path = '/v1/users/$userId/smart-wallets/$walletId';
    } else {
      path = '/v1/smart-wallets/$walletId';
    }

    return _safeExecute(
      uri: _buildUri(path),
      parser: (json) => EmbeddedWalletDetailResponse.fromJson(json),
    );
  }

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletBalanceResponse>> fetchBalance(String walletId) {
    final String path;
    if (isProxy) {
      path = '/wallets/$walletId/balance';
    } else if (userId != null && userId!.isNotEmpty) {
      path = '/v1/users/$userId/smart-wallets/$walletId/balance';
    } else {
      path = '/v1/smart-wallets/$walletId/balance';
    }

    return _safeExecute(
      uri: _buildUri(path),
      parser: (json) => EmbeddedWalletBalanceResponse.fromJson(json),
    );
  }

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletTransactionsResponse>> fetchTransactions(
    String walletId, {
    int? page,
    int? pageSize,
  }) {
    final String path;
    if (isProxy) {
      path = '/wallets/$walletId/transactions';
    } else if (userId != null && userId!.isNotEmpty) {
      path = '/v1/users/$userId/smart-wallets/$walletId/transactions';
    } else {
      path = '/v1/smart-wallets/$walletId/transactions';
    }

    final queryParams = <String, String>{
      if (page != null) 'page': page.toString(),
      if (pageSize != null) 'pageSize': pageSize.toString(),
    };

    return _safeExecute(
      uri: _buildUri(path, queryParams.isNotEmpty ? queryParams : null),
      parser: (json) => EmbeddedWalletTransactionsResponse.fromJson(json),
    );
  }
}
