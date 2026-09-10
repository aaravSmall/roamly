import 'package:flutter/material.dart';

import '../models/geo_photo.dart';
import '../models/home_location.dart';
import '../models/scan_result.dart';
import '../models/visit_models.dart';
import '../services/home_location_service.dart';
import '../services/manual_trip_service.dart';
import '../services/scan_cache_service.dart';
import '../services/trip_filter.dart';
import '../services/visit_builder.dart';
import 'home_screen.dart';
import 'my_info_screen.dart';
import 'world_map_screen.dart';

class RoamlyShell extends StatefulWidget {
  const RoamlyShell({super.key});

  @override
  State<RoamlyShell> createState() => _RoamlyShellState();
}

class _RoamlyShellState extends State<RoamlyShell> {
  final ScanCacheService _cacheService = ScanCacheService();
  final ManualTripService _manualTripService = ManualTripService();
  final HomeLocationService _homeLocationService = HomeLocationService();

  List<CountrySummary>? _countries;
  DateTime? _lastScannedAt;
  int? _totalPhotosAnalyzed;
  List<VisitSegment> _manualTrips = [];
  HomeLocation? _home;
  bool _cacheLoaded = false;

  /// The full resolved (unfiltered) photo list from the most recent scan,
  /// kept in memory only (not persisted) so changing home afterwards can
  /// re-filter and rebuild trips without a full photo-library re-scan. Lost
  /// on app restart — a fresh scan is the fallback then.
  List<TaggedPhoto>? _lastTaggedPhotos;

  int _tabIndex = 0;
  String? _focusCountryCode;

  /// [_countries] (photo-derived) merged with [_manualTrips] (hand-added),
  /// re-rolled into the same Country -> City -> Visit tree the rest of the
  /// UI expects. Null only when neither source has anything yet.
  List<CountrySummary>? get _displayCountries {
    if (_countries == null && _manualTrips.isEmpty) return null;
    final combined = [...VisitBuilder.flatten(_countries ?? const []), ..._manualTrips];
    return VisitBuilder.rollupByCountry(combined);
  }

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    final cachedFuture = _cacheService.load();
    final manualTripsFuture = _manualTripService.load();
    final homeFuture = _homeLocationService.load();
    final cached = await cachedFuture;
    final manualTrips = await manualTripsFuture;
    final home = await homeFuture;
    if (!mounted) return;
    setState(() {
      if (cached != null) {
        _countries = cached.countries;
        _lastScannedAt = cached.scannedAt;
        _totalPhotosAnalyzed = cached.totalPhotosAnalyzed;
      }
      _manualTrips = manualTrips;
      _home = home;
      _cacheLoaded = true;
    });
  }

  void _handleResultsChanged({
    required List<CountrySummary> countries,
    required DateTime scannedAt,
    required int totalPhotosAnalyzed,
    required List<TaggedPhoto> taggedPhotos,
  }) {
    setState(() {
      _countries = countries;
      _lastScannedAt = scannedAt;
      _totalPhotosAnalyzed = totalPhotosAnalyzed;
      _lastTaggedPhotos = taggedPhotos;
    });
  }

  /// Called whenever home is detected/confirmed/changed. If this session
  /// still has the last scan's resolved photos in memory, immediately
  /// re-filters and rebuilds trips against the new home — no re-scan
  /// needed. Otherwise the new home simply applies starting with the next
  /// scan (the documented fallback).
  void _handleHomeChanged(HomeLocation home) {
    setState(() => _home = home);

    final tagged = _lastTaggedPhotos;
    if (tagged == null) return;

    final filtered = filterOutHomeRadius(tagged, home);
    final summaries = VisitBuilder.buildFromTagged(filtered);
    final scannedAt = _lastScannedAt ?? DateTime.now();
    final totalPhotosAnalyzed = _totalPhotosAnalyzed ?? tagged.length;

    setState(() => _countries = summaries);
    _cacheService.save(
      ScanResult(
        scannedAt: scannedAt,
        countries: summaries,
        totalPhotosAnalyzed: totalPhotosAnalyzed,
      ),
    );
  }

  void _addManualTrip(VisitSegment segment) {
    setState(() => _manualTrips = [..._manualTrips, segment]);
    _manualTripService.save(_manualTrips);
  }

  void _deleteManualTrip(String manualId) {
    setState(
      () => _manualTrips = _manualTrips.where((s) => s.manualId != manualId).toList(),
    );
    _manualTripService.save(_manualTrips);
  }

  void _viewCountryTrips(String countryCode) {
    setState(() {
      _tabIndex = 0;
      _focusCountryCode = countryCode;
    });
  }

  void _clearFocusCountry() {
    setState(() => _focusCountryCode = null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_cacheLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final displayCountries = _displayCountries;

    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          HomeScreen(
            countries: displayCountries,
            lastScannedAt: _lastScannedAt,
            totalPhotosAnalyzed: _totalPhotosAnalyzed,
            home: _home,
            onResultsChanged: _handleResultsChanged,
            onHomeChanged: _handleHomeChanged,
            focusCountryCode: _focusCountryCode,
            onFocusHandled: _clearFocusCountry,
            onManualTripAdded: _addManualTrip,
            onDeleteManualTrip: _deleteManualTrip,
          ),
          WorldMapScreen(
            countries: displayCountries ?? const [],
            onViewCountryTrips: _viewCountryTrips,
          ),
          MyInfoScreen(
            countries: displayCountries,
            home: _home,
            onHomeChanged: _handleHomeChanged,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list), label: 'Trips'),
          NavigationDestination(icon: Icon(Icons.public), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Info'),
        ],
      ),
    );
  }
}
