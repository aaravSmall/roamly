import 'package:flutter/material.dart';

import '../models/visit_models.dart';
import '../services/scan_cache_service.dart';
import 'home_screen.dart';
import 'world_map_screen.dart';

class RoamlyShell extends StatefulWidget {
  const RoamlyShell({super.key});

  @override
  State<RoamlyShell> createState() => _RoamlyShellState();
}

class _RoamlyShellState extends State<RoamlyShell> {
  final ScanCacheService _cacheService = ScanCacheService();

  List<CountrySummary>? _countries;
  DateTime? _lastScannedAt;
  bool _cacheLoaded = false;

  int _tabIndex = 0;
  String? _focusCountryCode;

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    final cached = await _cacheService.load();
    if (!mounted) return;
    setState(() {
      if (cached != null) {
        _countries = cached.countries;
        _lastScannedAt = cached.scannedAt;
      }
      _cacheLoaded = true;
    });
  }

  void _handleResultsChanged(List<CountrySummary> countries, DateTime scannedAt) {
    setState(() {
      _countries = countries;
      _lastScannedAt = scannedAt;
    });
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

    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          HomeScreen(
            countries: _countries,
            lastScannedAt: _lastScannedAt,
            onResultsChanged: _handleResultsChanged,
            focusCountryCode: _focusCountryCode,
            onFocusHandled: _clearFocusCountry,
          ),
          WorldMapScreen(
            countries: _countries ?? const [],
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
