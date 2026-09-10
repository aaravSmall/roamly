import '../models/geo_photo.dart';
import '../models/home_location.dart';

/// Guesses which city is "home" from a set of geotagged photos: whichever
/// canonical city has the most photos, on the theory that a home city
/// dominates the photo library the way no vacation destination does.
class HomeDetector {
  HomeLocation? detectHome(List<TaggedPhoto> taggedPhotos) {
    if (taggedPhotos.isEmpty) return null;

    final groups = <String, List<TaggedPhoto>>{};
    for (final tagged in taggedPhotos) {
      groups.putIfAbsent(tagged.place.rollupKey, () => []).add(tagged);
    }

    List<TaggedPhoto>? bestGroup;
    for (final group in groups.values) {
      if (bestGroup == null || _isBetterHomeCandidate(group, bestGroup)) {
        bestGroup = group;
      }
    }

    final group = bestGroup!;
    final place = group.first.place;
    final latitude = group.map((t) => t.photo.lat).reduce((a, b) => a + b) / group.length;
    final longitude = group.map((t) => t.photo.lng).reduce((a, b) => a + b) / group.length;

    return HomeLocation(
      countryCode: place.countryCode,
      countryName: place.countryName,
      cityDisplayName: place.cityDisplayName,
      latitude: latitude,
      longitude: longitude,
      radiusMiles: 25.0,
      confirmed: false,
    );
  }

  /// True if [candidate] beats [current] as the home guess: more photos, or
  /// (tied) an earlier first photo, for deterministic results.
  bool _isBetterHomeCandidate(List<TaggedPhoto> candidate, List<TaggedPhoto> current) {
    if (candidate.length != current.length) return candidate.length > current.length;
    return _earliest(candidate).isBefore(_earliest(current));
  }

  DateTime _earliest(List<TaggedPhoto> photos) =>
      photos.map((t) => t.photo.takenAt).reduce((a, b) => a.isBefore(b) ? a : b);
}
