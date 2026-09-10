import '../models/home_location.dart';
import '../models/visit_models.dart';
import '../utils/distance.dart';

/// Aggregate stats over a (post-home-filter) Country/City/Visit tree, shown
/// on the My Info screen.
class TripStats {
  const TripStats({
    required this.totalTrips,
    required this.longestTrip,
    required this.farthestTrip,
    required this.mostVisitedCity,
    required this.mostVisitedCountry,
    required this.totalCountries,
    required this.totalCities,
  });

  final int totalTrips;

  /// By day span (`end.difference(start)`).
  final VisitSegment? longestTrip;

  /// By [haversineMiles] from home to the segment's centroid. Null if
  /// [home] wasn't supplied to [compute], or no segment has a centroid.
  final VisitSegment? farthestTrip;

  /// Most [VisitSegment]s, tie-broken by total photo count.
  final CitySummary? mostVisitedCity;

  /// Same logic as [mostVisitedCity], at the country level.
  final CountrySummary? mostVisitedCountry;

  final int totalCountries;
  final int totalCities;

  factory TripStats.compute(List<CountrySummary> countries, HomeLocation? home) {
    final allSegments = <VisitSegment>[
      for (final country in countries)
        for (final city in country.cities) ...city.segments,
    ];

    VisitSegment? longestTrip;
    for (final seg in allSegments) {
      if (longestTrip == null ||
          seg.end.difference(seg.start) > longestTrip.end.difference(longestTrip.start)) {
        longestTrip = seg;
      }
    }

    VisitSegment? farthestTrip;
    if (home != null) {
      double? farthestMiles;
      for (final seg in allSegments) {
        final lat = seg.centroidLatitude;
        final lng = seg.centroidLongitude;
        if (lat == null || lng == null) continue;
        final miles = haversineMiles(home.latitude, home.longitude, lat, lng);
        if (farthestTrip == null || miles > farthestMiles!) {
          farthestTrip = seg;
          farthestMiles = miles;
        }
      }
    }

    CitySummary? mostVisitedCity;
    for (final country in countries) {
      for (final city in country.cities) {
        if (mostVisitedCity == null || _cityBeats(city, mostVisitedCity)) {
          mostVisitedCity = city;
        }
      }
    }

    CountrySummary? mostVisitedCountry;
    for (final country in countries) {
      if (mostVisitedCountry == null || _countryBeats(country, mostVisitedCountry)) {
        mostVisitedCountry = country;
      }
    }

    return TripStats(
      totalTrips: allSegments.length,
      longestTrip: longestTrip,
      farthestTrip: farthestTrip,
      mostVisitedCity: mostVisitedCity,
      mostVisitedCountry: mostVisitedCountry,
      totalCountries: countries.length,
      totalCities: countries.fold(0, (sum, c) => sum + c.cities.length),
    );
  }

  static bool _cityBeats(CitySummary candidate, CitySummary current) {
    if (candidate.segments.length != current.segments.length) {
      return candidate.segments.length > current.segments.length;
    }
    return _photoCount(candidate) > _photoCount(current);
  }

  static int _photoCount(CitySummary city) =>
      city.segments.fold(0, (sum, s) => sum + s.photoCount);

  static bool _countryBeats(CountrySummary candidate, CountrySummary current) {
    final candidateTrips = candidate.cities.fold(0, (sum, c) => sum + c.segments.length);
    final currentTrips = current.cities.fold(0, (sum, c) => sum + c.segments.length);
    if (candidateTrips != currentTrips) return candidateTrips > currentTrips;
    return candidate.totalPhotos > current.totalPhotos;
  }
}
