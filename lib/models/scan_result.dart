import 'visit_models.dart';

class ScanResult {
  const ScanResult({
    required this.scannedAt,
    required this.countries,
    required this.totalPhotosAnalyzed,
  });

  final DateTime scannedAt;
  final List<CountrySummary> countries;

  /// Geotagged photos considered during the scan, before the home-radius
  /// filter excluded any of them from trips — kept for display (e.g. "342
  /// photos analyzed") even though not all of them end up in a trip.
  final int totalPhotosAnalyzed;

  Map<String, dynamic> toJson() => {
        'scannedAt': scannedAt.toIso8601String(),
        'countries': countries.map((c) => c.toJson()).toList(),
        'totalPhotosAnalyzed': totalPhotosAnalyzed,
      };

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final countries = (json['countries'] as List<dynamic>)
        .map((e) => CountrySummary.fromJson(e as Map<String, dynamic>))
        .toList();
    return ScanResult(
      scannedAt: DateTime.parse(json['scannedAt'] as String),
      countries: countries,
      // Older cached scans predate this field — approximate with the
      // photos that made it into a trip rather than crash or show 0.
      totalPhotosAnalyzed: json['totalPhotosAnalyzed'] as int? ??
          countries.fold<int>(0, (sum, c) => sum + c.totalPhotos),
    );
  }
}
