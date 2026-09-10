import '../models/geo_photo.dart';
import '../models/visit_models.dart';
import 'place_resolver.dart';

typedef ResolveProgress = void Function({required int done, required int total});

class VisitBuilder {
  VisitBuilder({PlaceResolver? resolver}) : _resolver = resolver ?? PlaceResolver();

  final PlaceResolver _resolver;

  /// Splits stays when chronological gap exceeds [maxGapDays] between photos.
  static const int maxGapDays = 14;

  /// Reverse-geocodes every photo into a [TaggedPhoto]. Split out from the
  /// old single-shot `buildFromPhotos` so callers can intervene between
  /// resolution and [buildFromTagged] — e.g. to detect/apply a home-radius
  /// filter before segments are built.
  Future<List<TaggedPhoto>> resolvePhotos(
    List<GeoPhoto> photos, {
    ResolveProgress? onResolveProgress,
  }) async {
    final tagged = <TaggedPhoto>[];
    final total = photos.length;

    for (var i = 0; i < photos.length; i++) {
      final p = photos[i];
      final place = await _resolver.resolve(p.lat, p.lng);
      tagged.add(TaggedPhoto(photo: p, place: place));
      onResolveProgress?.call(done: i + 1, total: total);
    }

    return tagged;
  }

  /// Builds the Country -> City -> Visit tree from already-resolved photos
  /// (see [resolvePhotos]).
  static List<CountrySummary> buildFromTagged(List<TaggedPhoto> taggedPhotos) {
    if (taggedPhotos.isEmpty) return [];
    final sorted = [...taggedPhotos]
      ..sort((a, b) => a.photo.takenAt.compareTo(b.photo.takenAt));
    final segments = _segmentsFromTagged(sorted);
    return rollupByCountry(segments);
  }

  /// Flattens a rolled-up country/city tree back into its individual
  /// segments, e.g. so manually-added trips can be merged in and the whole
  /// set re-rolled via [rollupByCountry].
  static List<VisitSegment> flatten(List<CountrySummary> countries) => [
        for (final country in countries)
          for (final city in country.cities) ...city.segments,
      ];

  static List<VisitSegment> _segmentsFromTagged(List<TaggedPhoto> sorted) {
    final out = <VisitSegment>[];
    var place = sorted.first.place;
    var start = sorted.first.photo.takenAt;
    var end = sorted.first.photo.takenAt;
    var photoIds = <String>[sorted.first.photo.assetId];
    var latSum = sorted.first.photo.lat;
    var lngSum = sorted.first.photo.lng;

    for (var i = 1; i < sorted.length; i++) {
      final cur = sorted[i];
      final prev = sorted[i - 1];
      final gapDays = cur.photo.takenAt.difference(prev.photo.takenAt).inDays;
      final samePlace = cur.place.sameCanonicalCity(place);

      if (samePlace && gapDays <= maxGapDays) {
        end = cur.photo.takenAt;
        photoIds.add(cur.photo.assetId);
        latSum += cur.photo.lat;
        lngSum += cur.photo.lng;
      } else {
        out.add(
          VisitSegment(
            place: place,
            start: start,
            end: end,
            photoCount: photoIds.length,
            photoIds: photoIds,
            centroidLatitude: latSum / photoIds.length,
            centroidLongitude: lngSum / photoIds.length,
          ),
        );
        place = cur.place;
        start = cur.photo.takenAt;
        end = cur.photo.takenAt;
        photoIds = <String>[cur.photo.assetId];
        latSum = cur.photo.lat;
        lngSum = cur.photo.lng;
      }
    }

    out.add(
      VisitSegment(
        place: place,
        start: start,
        end: end,
        photoCount: photoIds.length,
        photoIds: photoIds,
        centroidLatitude: latSum / photoIds.length,
        centroidLongitude: lngSum / photoIds.length,
      ),
    );
    return out;
  }

  static List<CountrySummary> rollupByCountry(List<VisitSegment> segments) {
    final byCountry = <String, List<VisitSegment>>{};
    final countryNames = <String, String>{};

    for (final seg in segments) {
      final code = seg.place.countryCode.toUpperCase();
      byCountry.putIfAbsent(code, () => []).add(seg);
      countryNames.putIfAbsent(code, () => seg.place.countryName);
    }

    final summaries = <CountrySummary>[];

    for (final entry in byCountry.entries) {
      final code = entry.key;
      final countrySegs = entry.value;

      final byCity = <String, List<VisitSegment>>{};
      for (final seg in countrySegs) {
        final city = seg.place.cityDisplayName;
        byCity.putIfAbsent(city, () => []).add(seg);
      }

      final cities = byCity.entries.map((e) {
        final segs = [...e.value]..sort((a, b) => b.start.compareTo(a.start));
        return CitySummary(cityName: e.key, segments: segs);
      }).toList()
        ..sort((a, b) => a.cityName.toLowerCase().compareTo(b.cityName.toLowerCase()));

      summaries.add(
        CountrySummary(
          countryCode: code,
          countryName: countryNames[code] ?? code,
          cities: cities,
        ),
      );
    }

    summaries.sort(
      (a, b) => a.countryName.toLowerCase().compareTo(b.countryName.toLowerCase()),
    );
    return summaries;
  }
}
