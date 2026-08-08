import 'package:flutter_test/flutter_test.dart';

import 'package:roamly/main.dart';

void main() {
  testWidgets('Roamly loads home shell', (WidgetTester tester) async {
    await tester.pumpWidget(const RoamlyApp());

    // RoamlyShell awaits a real (unmocked, file-I/O-backed) cache load
    // before it builds either tab. That's genuine async work outside the
    // fake test clock, so it needs runAsync to actually complete.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();

    expect(find.text('Roamly'), findsOneWidget);
  });
}
