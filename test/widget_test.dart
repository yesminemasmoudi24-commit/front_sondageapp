import 'package:flutter_test/flutter_test.dart';

import 'package:sondage_app/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const SondageApp());
    await tester.pump();
    expect(find.byType(SondageApp), findsOneWidget);
  });
}
