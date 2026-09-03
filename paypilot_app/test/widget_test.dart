import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';
import 'package:paypilot_app/main.dart';
import 'package:paypilot_app/services/wallet_read_data_source.dart';

void main() {
  testWidgets('PayPilot app loads without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const PayPilotApp());
    expect(find.byType(PayPilotApp), findsOneWidget);
  });

  group('EmbeddedWalletReadDataSource in PayPilot', () {
    test('uses correct sandbox URL and x-api-key header by default', () async {
      late http.Request sentRequest;
      final client = MockClient((request) async {
        sentRequest = request;
        return http.Response(
          jsonEncode([
            {
              'id': 'w_test',
              'currency': 'CNGN',
              'balance': 250000.0,
              'walletAddress': '0x123',
              'isActive': true,
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final dataSource = PayPilotWalletReadDataSource(
        client: client,
        userId: 'usr_mock_123',
      );

      final result = await dataSource.fetchWallets();

      expect(sentRequest.url.host, 'embedded-dev.bmoni.com');
      expect(
        sentRequest.headers['x-api-key'],
        'pk_a025cacbf33a_76fb864113f3540909de5b1da39cc146906e35b1c6d4d1e4',
      );
      expect(result.isRight(), isTrue);

      result.fold(
        (failure) => fail('Expected Right'),
        (response) {
          expect(response.wallets.length, 1);
          expect(response.wallets.first.walletId, 'w_test');
          expect(response.wallets.first.balance, 250000.0);
        },
      );
    });

    test('supports production base URL configuration', () async {
      late http.Request sentRequest;
      final client = MockClient((request) async {
        sentRequest = request;
        return http.Response(
          jsonEncode({
            'smartWalletId': 'w_prod_1',
            'balance': 1000.0,
            'currency': 'USD',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final dataSource = PayPilotWalletReadDataSource(
        client: client,
        baseUrl: BmoniUrls.production,
        apiKey: 'pk_my_production_partner_key',
        userId: 'usr_prod_1',
      );

      final result = await dataSource.fetchBalance('w_prod_1');

      expect(sentRequest.url.host, 'embedded.bmoni.com');
      expect(sentRequest.headers['x-api-key'], 'pk_my_production_partner_key');
      expect(result.isRight(), isTrue);
      result.fold(
        (failure) => fail('Expected Right'),
        (response) {
          expect(response.walletId, 'w_prod_1');
          expect(response.balance, 1000.0);
        },
      );
    });
  });
}
