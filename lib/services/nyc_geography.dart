import 'package:geocoding/geocoding.dart';

/// New York City's five boroughs align with five counties. Points in NJ stay NJ
/// (e.g. Bergen County / East Rutherford are never classified as NYC).
bool isNewYorkCityFromPlacemark(Placemark pm) {
  final iso = (pm.isoCountryCode ?? '').toUpperCase();
  if (iso != 'US') return false;

  final state = normalizeUsStateAbbrev(pm.administrativeArea);
  if (state != 'NY') return false;

  final county = normalizeCountyBase(pm.subAdministrativeArea);
  if (county.isNotEmpty) {
    const nycCounties = {'new york', 'kings', 'queens', 'bronx', 'richmond'};
    if (nycCounties.contains(county)) return true;
  }

  final loc = (pm.locality ?? '').trim().toLowerCase();
  if (loc.isEmpty) return false;

  const boroughLocalities = {
    'new york',
    'manhattan',
    'brooklyn',
    'queens',
    'bronx',
    'staten island',
  };
  return boroughLocalities.contains(loc);
}

String normalizeCountyBase(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  var s = raw.trim().toLowerCase();
  const suffix = ' county';
  if (s.endsWith(suffix)) {
    s = s.substring(0, s.length - suffix.length).trim();
  }
  return s;
}

String normalizeUsStateAbbrev(String? administrativeArea) {
  if (administrativeArea == null || administrativeArea.trim().isEmpty) {
    return '';
  }
  final s = administrativeArea.trim();
  final upper = s.toUpperCase();
  if (upper.length == 2) return upper;
  return _usFullStateNames[upper] ?? '';
}

/// Enough coverage that "New York" state resolves to NY; unknown full names
/// yield '' so NYC is never inferred without a reliable NY state field.
const Map<String, String> _usFullStateNames = {
  'ALABAMA': 'AL',
  'ALASKA': 'AK',
  'ARIZONA': 'AZ',
  'ARKANSAS': 'AR',
  'CALIFORNIA': 'CA',
  'COLORADO': 'CO',
  'CONNECTICUT': 'CT',
  'DELAWARE': 'DE',
  'FLORIDA': 'FL',
  'GEORGIA': 'GA',
  'HAWAII': 'HI',
  'IDAHO': 'ID',
  'ILLINOIS': 'IL',
  'INDIANA': 'IN',
  'IOWA': 'IA',
  'KANSAS': 'KS',
  'KENTUCKY': 'KY',
  'LOUISIANA': 'LA',
  'MAINE': 'ME',
  'MARYLAND': 'MD',
  'MASSACHUSETTS': 'MA',
  'MICHIGAN': 'MI',
  'MINNESOTA': 'MN',
  'MISSISSIPPI': 'MS',
  'MISSOURI': 'MO',
  'MONTANA': 'MT',
  'NEBRASKA': 'NE',
  'NEVADA': 'NV',
  'NEW HAMPSHIRE': 'NH',
  'NEW JERSEY': 'NJ',
  'NEW MEXICO': 'NM',
  'NEW YORK': 'NY',
  'NORTH CAROLINA': 'NC',
  'NORTH DAKOTA': 'ND',
  'OHIO': 'OH',
  'OKLAHOMA': 'OK',
  'OREGON': 'OR',
  'PENNSYLVANIA': 'PA',
  'RHODE ISLAND': 'RI',
  'SOUTH CAROLINA': 'SC',
  'SOUTH DAKOTA': 'SD',
  'TENNESSEE': 'TN',
  'TEXAS': 'TX',
  'UTAH': 'UT',
  'VERMONT': 'VT',
  'VIRGINIA': 'VA',
  'WASHINGTON': 'WA',
  'WEST VIRGINIA': 'WV',
  'WISCONSIN': 'WI',
  'WYOMING': 'WY',
  'DISTRICT OF COLUMBIA': 'DC',
};
