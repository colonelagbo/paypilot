import 'package:flutter_test/flutter_test.dart';
import 'package:paypilot_app/main.dart';

void main() {
  testWidgets('PayPilot app loads without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const PayPilotApp());
    expect(find.byType(PayPilotApp), findsOneWidget);
  });
}
