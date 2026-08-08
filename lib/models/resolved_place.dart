class ResolvedPlace {
  const ResolvedPlace({
    required this.countryCode,
    required this.countryName,
    required this.cityDisplayName,
  });

  final String countryCode;
  final String countryName;
  final String cityDisplayName;

  String get rollupKey =>
      '${countryCode.toUpperCase()}|${cityDisplayName.toLowerCase()}';

  bool sameCanonicalCity(ResolvedPlace other) => rollupKey == other.rollupKey;

  Map<String, dynamic> toJson() => {
        'countryCode': countryCode,
        'countryName': countryName,
        'cityDisplayName': cityDisplayName,
      };

  factory ResolvedPlace.fromJson(Map<String, dynamic> json) => ResolvedPlace(
        countryCode: json['countryCode'] as String,
        countryName: json['countryName'] as String,
        cityDisplayName: json['cityDisplayName'] as String,
      );
}
