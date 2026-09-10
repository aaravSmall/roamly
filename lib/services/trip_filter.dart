import '../models/geo_photo.dart';
import '../models/home_location.dart';
import '../utils/distance.dart';

/// Excludes photos taken within [HomeLocation.radiusMiles] of home — the
/// idea being day-to-day photos near home shouldn't register as a "trip".
/// Returns [photos] unchanged if [home] is null.
List<TaggedPhoto> filterOutHomeRadius(List<TaggedPhoto> photos, HomeLocation? home) {
  if (home == null) return photos;
  return photos
      .where(
        (tagged) => haversineMiles(
              tagged.photo.lat,
              tagged.photo.lng,
              home.latitude,
              home.longitude,
            ) >
            home.radiusMiles,
      )
      .toList();
}
