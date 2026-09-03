import 'dart:convert';
import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('BmoniUrls Constants', () {
    test('contains exact production and development base URLs', () {
      expect(BmoniUrls.production, 'https://embedded.bmoni.com');
      expect(BmoniUrls.development, 'https://embedded-dev.bmoni.com');
      expect(BmoniUrls.sandbox, 'https://embedded-dev.bmoni.com');
      expect(
        BmoniUrls.sandboxSharedApiKey,
        'pk_a025cacbf33a_76fb864113f3540909de5b1da39cc146906e35b1c6d4d1e4',
      );
      expect(BmoniUrls.apiKeyHeader, 'x-api-key');
    });
  });

  group('BmoniEmbeddedWalletRemoteDataSource', () {
    const testApiKey = 'pk_test_12345';
    const testUserId = 'usr_test_bmoni';

    test('fetchWallets sends x-api-key header and parses list response', () async {
      late http.Request capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode([
            {
              'id': 'wlt_1',
              'currency': 'CNGN',
              'balance': 150000.50,
              'walletAddress': '0x1111111111111111111111111111111111111111',
              'isActive': true,
            },
            {
              'id': 'wlt_2',
              'currency': 'USD',
              'balance': 500.00,
              'walletAddress': '0x2222222222222222222222222222222222222222',
              'isActive': true,
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final dataSource = BmoniEmbeddedWalletRemoteDataSource(
        client: mockClient,
        baseUrl: BmoniUrls.development,
        apiKey: testApiKey,
        userId: testUserId,
      );

      final result = await dataSource.fetchWallets();

      expect(capturedRequest.headers['x-api-key'], testApiKey);
      expect(
        capturedRequest.url.path,
        '/v1/users/$testUserId/smart-wallets/account/wallets',
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (failure) => fail('Expected Right but got Left: $failure'),
        (response) {
          expect(response.wallets.length, 2);
          expect(response.wallets[0].walletId, 'wlt_1');
          expect(response.wallets[0].currency, 'CNGN');
          expect(response.wallets[0].balance, 150000.50);
          expect(response.wallets[1].walletId, 'wlt_2');
        },
      );
    });

    test('fetchWalletDetail fetches single wallet and parses response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 'wlt_1',
            'currency': 'CNGN',
            'balance': 75000.0,
            'walletAddress': '0x1234567890123456789012345678901234567890',
            'isActive': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final dataSource = BmoniEmbeddedWalletRemoteDataSource(
        client: mockClient,
        userId: testUserId,
      );

      final result = await dataSource.fetchWalletDetail('wlt_1');

      expect(result.isRight(), isTrue);
      result.fold(
        (failure) => fail('Expected Right'),
        (response) {
          expect(response.wallet.walletId, 'wlt_1');
          expect(response.wallet.balance, 75000.0);
        },
      );
    });

    test('fetchBalance returns balance response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'smartWalletId': 'wlt_1',
            'balance': '2500.75',
            'currency': 'CNGN',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final dataSource = BmoniEmbeddedWalletRemoteDataSource(
        client: mockClient,
        userId: testUserId,
      );

      final result = await dataSource.fetchBalance('wlt_1');

      expect(result.isRight(), isTrue);
      result.fold(
        (failure) => fail('Expected Right'),
        (response) {
          expect(response.walletId, 'wlt_1');
          expect(response.balance, 2500.75);
          expect(response.currency, 'CNGN');
        },
      );
    });

    test('fetchTransactions parses list of transactions and query params', () async {
      late http.Request capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'data': {
              'transactions': [
                {
                  'id': 'tx_1',
                  'walletId': 'wlt_1',
                  'amount': 50000.0,
                  'currency': 'CNGN',
                  'direction': 'incoming',
                  'status': 'completed',
                  'title': 'Salary deposit',
                  'reference': 'BMONI-12345',
                }
              ]
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final dataSource = BmoniEmbeddedWalletRemoteDataSource(
        client: mockClient,
        userId: testUserId,
      );

      final result = await dataSource.fetchTransactions('wlt_1', page: 1, pageSize: 10);

      expect(capturedRequest.url.queryParameters['page'], '1');
      expect(capturedRequest.url.queryParameters['pageSize'], '10');

      expect(result.isRight(), isTrue);
      result.fold(
        (failure) => fail('Expected Right'),
        (response) {
          expect(response.transactions.length, 1);
          final tx = response.transactions.first;
          expect(tx.id, 'tx_1');
          expect(tx.amount, 50000.0);
          expect(tx.isIncoming, isTrue);
          expect(tx.status, EmbeddedWalletTransactionStatus.completed);
          expect(tx.reference, 'BMONI-12345');
        },
      );
    });

    test('maps 401 response to EmbeddedAuthenticationFailure', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Missing or invalid API key'}),
          401,
        );
      });

      final dataSource = BmoniEmbeddedWalletRemoteDataSource(
        client: mockClient,
        userId: testUserId,
      );

      final result = await dataSource.fetchWallets();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<EmbeddedAuthenticationFailure>());
          expect(failure.statusCode, 401);
          expect(failure.message, contains('Missing or invalid API key'));
        },
        (_) => fail('Expected Left'),
      );
    });

    test('maps 404 response to EmbeddedNotFoundFailure', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Smart wallet not found'}),
          404,
        );
      });

      final dataSource = BmoniEmbeddedWalletRemoteDataSource(
        client: mockClient,
        userId: testUserId,
      );

      final result = await dataSource.fetchWalletDetail('unknown_id');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<EmbeddedNotFoundFailure>());
          expect(failure.statusCode, 404);
        },
        (_) => fail('Expected Left'),
      );
    });

    test('BmoniEmbeddedSdk.createReadDataSource returns configured instance', () {
      final ds = BmoniEmbeddedSdk.createReadDataSource(
        baseUrl: BmoniUrls.production,
        apiKey: 'custom_prod_key',
        userId: 'custom_user',
      );
      expect(ds, isA<EmbeddedWalletReadDataSource>());
    });
  });

  group('InMemory Storage & Cache Contracts', () {
    test('InMemoryEmbeddedWalletStorage saves and loads data', () async {
      final storage = InMemoryEmbeddedWalletStorage();
      expect(await storage.loadWallets(), isNull);

      const wallet = EmbeddedWallet(
        walletId: 'w_1',
        name: 'Main Wallet',
        currency: 'CNGN',
        balance: 1000.0,
      );
      await storage.saveWallets([wallet]);

      final loaded = await storage.loadWallets();
      expect(loaded, isNotNull);
      expect(loaded!.length, 1);
      expect(loaded.first.walletId, 'w_1');

      const tx = EmbeddedWalletTransaction(
        id: 'tx_1',
        walletId: 'w_1',
        amount: 250.0,
      );
      await storage.saveTransactions('w_1', [tx]);
      final loadedTxs = await storage.loadTransactions('w_1');
      expect(loadedTxs?.length, 1);
      expect(loadedTxs?.first.id, 'tx_1');
    });

    test('InMemoryEmbeddedWalletBalanceCache saves, loads and clears balances', () async {
      final cache = InMemoryEmbeddedWalletBalanceCache();
      expect(await cache.loadBalance('w_1'), isNull);

      await cache.saveBalance('w_1', 12345.67);
      expect(await cache.loadBalance('w_1'), 12345.67);

      await cache.clearAll();
      expect(await cache.loadBalance('w_1'), isNull);
    });
  });
}
