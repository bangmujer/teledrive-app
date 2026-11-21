import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teledrive/main.dart';

void main() {
  testWidgets('TeleDrive app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const TeleDriveApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
