import 'package:flutter_test/flutter_test.dart';

import 'package:roamly/main.dart';

void main() {
  testWidgets('Roamly loads home shell', (WidgetTester tester) async {
    await tester.pumpWidget(const RoamlyApp());
    await tester.pump();

    expect(find.text('Roamly'), findsOneWidget);
  });
}
