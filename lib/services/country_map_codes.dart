/// Converts an ISO 3166-1 alpha-2 country code (as stored in
/// `ResolvedPlace.countryCode`, e.g. "US", "FR") into the id the
/// `countries_world_map` package uses to key its drawing instructions and
/// `colors` map.
///
/// Verified directly against the package source (countries_world_map 1.3.0,
/// `lib/data/maps/world_map.dart`): every territory's `"u"` id embedded in
/// `SMapWorld.instructionsMercator`'s drawing data — and looked up via
/// `colors?[uniqueID]` in the painter — is a plain lowercase two-letter code
/// (e.g. `"us"`, `"fr"`, plus the unofficial `"xk"` for Kosovo). The
/// camelCase names (`uS`, `fR`, ...) only exist as `SMapWorldColors`' Dart
/// constructor parameter names; its own `toMap()` lowercases them right back
/// down, so camelCase is never what the widget actually matches on.
String worldMapCountryId(String isoCountryCode) => isoCountryCode.toLowerCase();
