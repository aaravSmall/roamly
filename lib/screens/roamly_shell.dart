import 'package:flutter/material.dart';

import '../models/visit_models.dart';
import '../services/manual_trip_service.dart';
import '../services/scan_cache_service.dart';
import '../services/visit_builder.dart';
import 'home_screen.dart';
import 'world_map_screen.dart';

class RoamlyShell extends StatefulWidget {
  const RoamlyShell({super.key});

  @override
  State<RoamlyShell> createState() => _RoamlyShellState();
}

class _RoamlyShellState extends State<RoamlyShell> {
  final ScanCacheService _cacheService = ScanCacheService();
  final ManualTripService _manualTripService = ManualTripService();

  List<CountrySummary>? _countries;
  DateTime? _lastScannedAt;
  List<VisitSegment> _manualTrips = [];
  bool _cacheLoaded = false;

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
    final cached = await cachedFuture;
    final manualTrips = await manualTripsFuture;
    if (!mounted) return;
    setState(() {
      if (cached != null) {
        _countries = cached.countries;
        _lastScannedAt = cached.scannedAt;
      }
      _manualTrips = manualTrips;
      _cacheLoaded = true;
    });
  }

  void _handleResultsChanged(List<CountrySummary> countries, DateTime scannedAt) {
    setState(() {
      _countries = countries;
      _lastScannedAt = scannedAt;
    });
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
            onResultsChanged: _handleResultsChanged,
            focusCountryCode: _focusCountryCode,
            onFocusHandled: _clearFocusCountry,
            onManualTripAdded: _addManualTrip,
            onDeleteManualTrip: _deleteManualTrip,
          ),
          WorldMapScreen(
            countries: displayCountries ?? const [],
            onViewCountryTrips: _viewCountryTrips,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list), label: 'Trips'),
          NavigationDestination(icon: Icon(Icons.public), label: 'Map'),
        ],
      ),
    );
  }
}
