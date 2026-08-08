import 'package:flutter_test/flutter_test.dart';
import 'package:roamly/models/resolved_place.dart';
import 'package:roamly/models/visit_models.dart';

void main() {
  group('VisitSegment JSON round-trip', () {
    test('preserves every field through toJson/fromJson', () {
      const place = ResolvedPlace(
        countryCode: 'US',
        countryName: 'United States',
        cityDisplayName: 'New York City',
      );
      final segment = VisitSegment(
        place: place,
        start: DateTime.utc(2024, 1, 2, 10, 30),
        end: DateTime.utc(2024, 1, 9, 18, 0),
        photoCount: 2,
        photoIds: const ['asset-1', 'asset-2'],
      );

      final decoded = VisitSegment.fromJson(segment.toJson());

      expect(decoded.place.countryCode, segment.place.countryCode);
      expect(decoded.place.countryName, segment.place.countryName);
      expect(decoded.place.cityDisplayName, segment.place.cityDisplayName);
      expect(decoded.start, segment.start);
      expect(decoded.end, segment.end);
      expect(decoded.photoCount, segment.photoCount);
      expect(decoded.photoIds, segment.photoIds);
    });
  });

  group('CountrySummary JSON round-trip', () {
    test('preserves nested cities and segments through toJson/fromJson', () {
      const usPlace = ResolvedPlace(
        countryCode: 'US',
        countryName: 'United States',
        cityDisplayName: 'New York City',
      );

      final segmentA = VisitSegment(
        place: usPlace,
        start: DateTime.utc(2023, 5, 1),
        end: DateTime.utc(2023, 5, 3),
        photoCount: 3,
        photoIds: const ['a1', 'a2', 'a3'],
      );
      final segmentB = VisitSegment(
        place: usPlace,
        start: DateTime.utc(2023, 8, 10),
        end: DateTime.utc(2023, 8, 12),
        photoCount: 1,
        photoIds: const ['a4'],
      );

      final city = CitySummary(
        cityName: 'New York City',
        segments: [segmentB, segmentA],
      );
      final country = CountrySummary(
        countryCode: 'US',
        countryName: 'United States',
        cities: [city],
      );

      final decoded = CountrySummary.fromJson(country.toJson());

      expect(decoded.countryCode, country.countryCode);
      expect(decoded.countryName, country.countryName);
      expect(decoded.cities.length, country.cities.length);

      final decodedCity = decoded.cities.single;
      expect(decodedCity.cityName, city.cityName);
      expect(decodedCity.segments.length, city.segments.length);

      for (var i = 0; i < city.segments.length; i++) {
        final expectedSeg = city.segments[i];
        final actualSeg = decodedCity.segments[i];
        expect(actualSeg.place.countryCode, expectedSeg.place.countryCode);
        expect(actualSeg.place.countryName, expectedSeg.place.countryName);
        expect(
          actualSeg.place.cityDisplayName,
          expectedSeg.place.cityDisplayName,
        );
        expect(actualSeg.start, expectedSeg.start);
        expect(actualSeg.end, expectedSeg.end);
        expect(actualSeg.photoCount, expectedSeg.photoCount);
        expect(actualSeg.photoIds, expectedSeg.photoIds);
      }

      expect(decoded.totalPhotos, country.totalPhotos);
    });
  });
}
