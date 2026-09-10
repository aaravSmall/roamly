import 'resolved_place.dart';

class VisitSegment {
  const VisitSegment({
    required this.place,
    required this.start,
    required this.end,
    required this.photoCount,
    required this.photoIds,
    this.manualId,
    this.centroidLatitude,
    this.centroidLongitude,
  });

  final ResolvedPlace place;
  final DateTime start;
  final DateTime end;
  final int photoCount;

  /// AssetEntity ids (from photo_manager) of every photo merged into this segment.
  final List<String> photoIds;

  /// Set (to a unique id) only for trips added by hand via the "Add trip"
  /// form, rather than derived from geotagged photos. Used to find this
  /// segment again in [ManualTripService]'s list for deletion.
  final String? manualId;

  /// Mean coordinates of the photos merged into this segment. Null for
  /// manually-added trips (no photos) and for segments loaded from
  /// pre-existing cached JSON that predates these fields.
  final double? centroidLatitude;
  final double? centroidLongitude;

  bool get isManual => manualId != null;

  Map<String, dynamic> toJson() => {
        'place': place.toJson(),
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'photoCount': photoCount,
        'photoIds': photoIds,
        'manualId': manualId,
        'centroidLatitude': centroidLatitude,
        'centroidLongitude': centroidLongitude,
      };

  factory VisitSegment.fromJson(Map<String, dynamic> json) => VisitSegment(
        place: ResolvedPlace.fromJson(json['place'] as Map<String, dynamic>),
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        photoCount: json['photoCount'] as int,
        photoIds: (json['photoIds'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        manualId: json['manualId'] as String?,
        centroidLatitude: (json['centroidLatitude'] as num?)?.toDouble(),
        centroidLongitude: (json['centroidLongitude'] as num?)?.toDouble(),
      );
}

class CitySummary {
  const CitySummary({required this.cityName, required this.segments});

  final String cityName;
  final List<VisitSegment> segments;

  Map<String, dynamic> toJson() => {
        'cityName': cityName,
        'segments': segments.map((s) => s.toJson()).toList(),
      };

  factory CitySummary.fromJson(Map<String, dynamic> json) => CitySummary(
        cityName: json['cityName'] as String,
        segments: (json['segments'] as List<dynamic>)
            .map((e) => VisitSegment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CountrySummary {
  const CountrySummary({
    required this.countryCode,
    required this.countryName,
    required this.cities,
  });

  final String countryCode;
  final String countryName;
  final List<CitySummary> cities;

  int get totalPhotos =>
      cities.fold(0, (sum, c) => sum + c.segments.fold(0, (s, v) => s + v.photoCount));

  Map<String, dynamic> toJson() => {
        'countryCode': countryCode,
        'countryName': countryName,
        'cities': cities.map((c) => c.toJson()).toList(),
      };

  factory CountrySummary.fromJson(Map<String, dynamic> json) => CountrySummary(
        countryCode: json['countryCode'] as String,
        countryName: json['countryName'] as String,
        cities: (json['cities'] as List<dynamic>)
            .map((e) => CitySummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
