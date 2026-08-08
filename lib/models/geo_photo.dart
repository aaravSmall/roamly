import 'resolved_place.dart';

class GeoPhoto {
  const GeoPhoto({
    required this.assetId,
    required this.takenAt,
    required this.lat,
    required this.lng,
  });

  final String assetId;
  final DateTime takenAt;
  final double lat;
  final double lng;
}

class TaggedPhoto {
  const TaggedPhoto({required this.photo, required this.place});

  final GeoPhoto photo;
  final ResolvedPlace place;
}
