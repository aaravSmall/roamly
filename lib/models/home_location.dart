class HomeLocation {
  const HomeLocation({
    required this.countryCode,
    required this.countryName,
    required this.cityDisplayName,
    required this.latitude,
    required this.longitude,
    this.radiusMiles = 25.0,
    this.confirmed = false,
  });

  final String countryCode;
  final String countryName;
  final String cityDisplayName;
  final double latitude;
  final double longitude;
  final double radiusMiles;

  /// Whether the user has confirmed/edited this home, vs. it still being a
  /// raw auto-detected guess.
  final bool confirmed;

  Map<String, dynamic> toJson() => {
        'countryCode': countryCode,
        'countryName': countryName,
        'cityDisplayName': cityDisplayName,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMiles': radiusMiles,
        'confirmed': confirmed,
      };

  factory HomeLocation.fromJson(Map<String, dynamic> json) => HomeLocation(
        countryCode: json['countryCode'] as String,
        countryName: json['countryName'] as String,
        cityDisplayName: json['cityDisplayName'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        radiusMiles: (json['radiusMiles'] as num?)?.toDouble() ?? 25.0,
        confirmed: json['confirmed'] as bool? ?? false,
      );
}
