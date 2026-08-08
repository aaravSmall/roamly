import 'visit_models.dart';

class ScanResult {
  const ScanResult({required this.scannedAt, required this.countries});

  final DateTime scannedAt;
  final List<CountrySummary> countries;

  Map<String, dynamic> toJson() => {
        'scannedAt': scannedAt.toIso8601String(),
        'countries': countries.map((c) => c.toJson()).toList(),
      };

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
        scannedAt: DateTime.parse(json['scannedAt'] as String),
        countries: (json['countries'] as List<dynamic>)
            .map((e) => CountrySummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
