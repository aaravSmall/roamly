import '../models/home_location.dart';
import '../models/visit_models.dart';

/// One candidate "home" per city already seen in [countries], each with its
/// total photo count, sorted most-photographed first. Powers the "Not
/// quite, it's actually..." picker in [HomeConfirmScreen] — built from
/// already-resolved scan data (segment centroids), so picking a different
/// city needs no new geocoding calls.
List<({HomeLocation home, int photoCount})> homeCandidatesFromCountries(
  List<CountrySummary> countries,
) {
  final candidates = <({HomeLocation home, int photoCount})>[];

  for (final country in countries) {
    for (final city in country.cities) {
      final withCentroid = city.segments
          .where((s) => s.centroidLatitude != null && s.centroidLongitude != null)
          .toList();
      final totalPhotos = withCentroid.fold<int>(0, (sum, s) => sum + s.photoCount);
      if (totalPhotos == 0) continue;

      final latitude = withCentroid.fold<double>(
            0,
            (sum, s) => sum + s.centroidLatitude! * s.photoCount,
          ) /
          totalPhotos;
      final longitude = withCentroid.fold<double>(
            0,
            (sum, s) => sum + s.centroidLongitude! * s.photoCount,
          ) /
          totalPhotos;

      candidates.add((
        home: HomeLocation(
          countryCode: country.countryCode,
          countryName: country.countryName,
          cityDisplayName: city.cityName,
          latitude: latitude,
          longitude: longitude,
        ),
        photoCount: totalPhotos,
      ));
    }
  }

  candidates.sort((a, b) => b.photoCount.compareTo(a.photoCount));
  return candidates;
}
