import 'package:roamly/services/nyc_geography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';

void main() {
  group('isNewYorkCityFromPlacemark', () {
    test('Queens NY with Queens County counts as NYC', () {
      final pm = Placemark(
        isoCountryCode: 'US',
        administrativeArea: 'NY',
        subAdministrativeArea: 'Queens County',
        locality: 'Queens',
      );
      expect(isNewYorkCityFromPlacemark(pm), isTrue);
    });

    test('East Rutherford NJ is not NYC', () {
      final pm = Placemark(
        isoCountryCode: 'US',
        administrativeArea: 'NJ',
        subAdministrativeArea: 'Bergen County',
        locality: 'East Rutherford',
      );
      expect(isNewYorkCityFromPlacemark(pm), isFalse);
    });

    test('London GB is never NYC via county logic', () {
      final pm = Placemark(
        isoCountryCode: 'GB',
        administrativeArea: 'England',
        locality: 'London',
      );
      expect(isNewYorkCityFromPlacemark(pm), isFalse);
    });
  });
}
