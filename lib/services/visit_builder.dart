import '../models/geo_photo.dart';
import '../models/visit_models.dart';
import 'place_resolver.dart';

typedef ResolveProgress = void Function({required int done, required int total});

class VisitBuilder {
  VisitBuilder({PlaceResolver? resolver}) : _resolver = resolver ?? PlaceResolver();

  final PlaceResolver _resolver;

  /// Splits stays when chronological gap exceeds [maxGapDays] between photos.
  static const int maxGapDays = 14;

  Future<List<CountrySummary>> buildFromPhotos(
    List<GeoPhoto> photos, {
    ResolveProgress? onResolveProgress,
  }) async {
    if (photos.isEmpty) return [];

    final tagged = <TaggedPhoto>[];
    final total = photos.length;

    for (var i = 0; i < photos.length; i++) {
      final p = photos[i];
      final place = await _resolver.resolve(p.lat, p.lng);
      tagged.add(TaggedPhoto(photo: p, place: place));
      onResolveProgress?.call(done: i + 1, total: total);
    }

    tagged.sort((a, b) => a.photo.takenAt.compareTo(b.photo.takenAt));
    final segments = _segmentsFromTagged(tagged);
    return _rollupByCountry(segments);
  }

  List<VisitSegment> _segmentsFromTagged(List<TaggedPhoto> sorted) {
    final out = <VisitSegment>[];
    var place = sorted.first.place;
    var start = sorted.first.photo.takenAt;
    var end = sorted.first.photo.takenAt;
    var photoIds = <String>[sorted.first.photo.assetId];

    for (var i = 1; i < sorted.length; i++) {
      final cur = sorted[i];
      final prev = sorted[i - 1];
      final gapDays = cur.photo.takenAt.difference(prev.photo.takenAt).inDays;
      final samePlace = cur.place.sameCanonicalCity(place);

      if (samePlace && gapDays <= maxGapDays) {
        end = cur.photo.takenAt;
        photoIds.add(cur.photo.assetId);
      } else {
        out.add(
          VisitSegment(
            place: place,
            start: start,
            end: end,
            photoCount: photoIds.length,
            photoIds: photoIds,
          ),
        );
        place = cur.place;
        start = cur.photo.takenAt;
        end = cur.photo.takenAt;
        photoIds = <String>[cur.photo.assetId];
      }
    }

    out.add(
      VisitSegment(
        place: place,
        start: start,
        end: end,
        photoCount: photoIds.length,
        photoIds: photoIds,
      ),
    );
    return out;
  }

  List<CountrySummary> _rollupByCountry(List<VisitSegment> segments) {
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
