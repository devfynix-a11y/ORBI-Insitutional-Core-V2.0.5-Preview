import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_mobileapp/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const OrbiApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
