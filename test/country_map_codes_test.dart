import 'package:flutter_test/flutter_test.dart';
import 'package:roamly/services/country_map_codes.dart';

// A sample of ids pulled directly from countries_world_map 1.3.0's
// SMapWorld.instructionsMercator drawing data (grep for `"u": "xx"` in
// lib/data/maps/world_map.dart), used here to confirm worldMapCountryId
// produces ids the package actually recognizes rather than guessed ones.
const Set<String> _verifiedPackageIds = {
  'us', 'fr', 'gb', 'jp', 'de', 'ci', 'cd', 'cg', 'xk',
};

void main() {
  group('worldMapCountryId', () {
    test('lowercases standard ISO alpha-2 codes', () {
      expect(worldMapCountryId('US'), 'us');
      expect(worldMapCountryId('FR'), 'fr');
      expect(worldMapCountryId('GB'), 'gb');
      expect(worldMapCountryId('JP'), 'jp');
      expect(worldMapCountryId('DE'), 'de');
    });

    test('leaves already-lowercase codes unchanged', () {
      expect(worldMapCountryId('us'), 'us');
    });

    test('handles the unofficial Kosovo code used by the package', () {
      // Kosovo has no official ISO 3166-1 code; countries_world_map uses the
      // commonly-adopted unofficial "xk" / "XK".
      expect(worldMapCountryId('XK'), 'xk');
    });

    test('handles multi-word country names via their plain two-letter code', () {
      // "Cote d'Ivoire", "DR Congo" and "Republic of the Congo" are
      // multi-word names, but the package still keys them with a plain
      // two-letter id (not a camelCase or word-based id).
      expect(worldMapCountryId('CI'), 'ci'); // Cote d'Ivoire
      expect(worldMapCountryId('CD'), 'cd'); // DR Congo
      expect(worldMapCountryId('CG'), 'cg'); // Republic of the Congo
    });

    test('produces ids that match the verified package id set', () {
      for (final id in _verifiedPackageIds) {
        expect(worldMapCountryId(id.toUpperCase()), id);
      }
    });

    test('an unresolved place code does not collide with any real id', () {
      // PlaceResolver falls back to '??' when geocoding fails; that must
      // never accidentally match a real territory id.
      expect(_verifiedPackageIds.contains(worldMapCountryId('??')), isFalse);
    });
  });
}
