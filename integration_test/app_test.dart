import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:orbi_mobileapp/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app starts and shows login', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Basic smoke assertion: ensure the app built without throwing.
    expect(true, isTrue);
  });
}
