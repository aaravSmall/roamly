import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamly/models/resolved_place.dart';
import 'package:roamly/models/visit_models.dart';
import 'package:roamly/screens/visit_detail_screen.dart';

void main() {
  testWidgets(
    'shows a tile per photoId and tapping one opens the full-screen viewer',
    (tester) async {
      final segment = VisitSegment(
        place: const ResolvedPlace(
          countryCode: 'FR',
          countryName: 'France',
          cityDisplayName: 'Paris',
        ),
        start: DateTime.utc(2025, 8, 3),
        end: DateTime.utc(2025, 8, 9),
        photoCount: 2,
        photoIds: const ['asset-1', 'asset-2'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: VisitDetailScreen(
            segment: segment,
            cityName: 'Paris',
            countryName: 'France',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Paris, France — Aug 3 – Aug 9, 2025'), findsOneWidget);
      expect(find.byKey(const ValueKey('photo-tile-asset-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('photo-tile-asset-2')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('photo-tile-asset-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
    },
  );
}
