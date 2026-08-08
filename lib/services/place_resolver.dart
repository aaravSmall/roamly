import 'package:geocoding/geocoding.dart';

import '../models/resolved_place.dart';
import 'nyc_geography.dart';

class PlaceResolver {
  final Map<String, ResolvedPlace> _cache = {};

  String _cacheKey(double lat, double lng) =>
      '${(lat * 1e4).round()}_${(lng * 1e4).round()}';

  Future<ResolvedPlace> resolve(double lat, double lng) async {
    final key = _cacheKey(lat, lng);
    final hit = _cache[key];
    if (hit != null) return hit;

    List<Placemark> marks;
    try {
      marks = await placemarkFromCoordinates(lat, lng);
    } catch (_) {
      const unk = ResolvedPlace(
        countryCode: '??',
        countryName: 'Unknown',
        cityDisplayName: 'Unknown',
      );
      _cache[key] = unk;
      return unk;
    }

    if (marks.isEmpty) {
      const unk = ResolvedPlace(
        countryCode: '??',
        countryName: 'Unknown',
        cityDisplayName: 'Unknown',
      );
      _cache[key] = unk;
      return unk;
    }

    final pm = marks.first;
    final isNyc = isNewYorkCityFromPlacemark(pm);
    final city = isNyc ? 'New York City' : _pickCityDisplayName(pm);

    final iso = (pm.isoCountryCode ?? '').trim().toUpperCase();
    final countryName = (pm.country ?? '').trim();

    final place = ResolvedPlace(
      countryCode: iso.isEmpty ? '??' : iso,
      countryName: countryName.isEmpty ? 'Unknown' : countryName,
      cityDisplayName: city.isEmpty ? 'Unknown' : city,
    );
    _cache[key] = place;
    return place;
  }

  String _pickCityDisplayName(Placemark pm) {
    final loc = pm.locality?.trim();
    if (loc != null && loc.isNotEmpty) return loc;

    final sub = pm.subAdministrativeArea?.trim();
    if (sub != null &&
        sub.isNotEmpty &&
        !_looksLikeUnitedStatesCountyLabel(sub)) {
      return sub;
    }

    final admin = pm.administrativeArea?.trim();
    if (admin != null && admin.isNotEmpty) return admin;

    return 'Unknown';
  }

  bool _looksLikeUnitedStatesCountyLabel(String s) {
    final lower = s.toLowerCase();
    return lower.endsWith(' county') || lower.endsWith(' parish');
  }
}
