import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';

import '../photo_permission.dart';
import '../theme/roamly_theme.dart';
import '../models/scan_result.dart';
import '../models/visit_models.dart';
import '../services/photo_scan_service.dart';
import '../services/scan_cache_service.dart';
import '../services/visit_builder.dart';
import '../utils/date_range_format.dart';
import 'visit_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  PermissionState? _permissionState;
  List<CountrySummary>? _countries;
  DateTime? _lastUpdated;

  bool _loadingPermission = true;
  bool _scanning = false;
  String _statusLine = '';

  double? _phaseProgress;

  final VisitBuilder _visitBuilder = VisitBuilder();
  final ScanCacheService _cacheService = ScanCacheService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    await _loadCache();
    await _syncPermission();
  }

  Future<void> _loadCache() async {
    final cached = await _cacheService.load();
    if (!mounted || cached == null) return;
    setState(() {
      _countries = cached.countries;
      _lastUpdated = cached.scannedAt;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncPermission();
    }
  }

  Future<void> _syncPermission() async {
    setState(() => _loadingPermission = true);
    final state =
        await PhotoManager.getPermissionState(requestOption: kPhotoPermissionOption);
    setState(() {
      _permissionState = state;
      _loadingPermission = false;
    });
  }

  Future<void> _requestAccess() async {
    await PhotoManager.requestPermissionExtend(
      requestOption: kPhotoPermissionOption,
    );
    await _syncPermission();
  }

  Future<void> _openOsSettings() async {
    await PhotoManager.openSetting();
  }

  Future<void> _runScan() async {
    final ps = _permissionState;
    if (ps == null || !ps.hasAccess) {
      await _requestAccess();
      if (_permissionState == null || !_permissionState!.hasAccess) return;
    }

    setState(() {
      _scanning = true;
      _phaseProgress = 0;
      _statusLine = 'Reading photo library…';
    });

    try {
      final geoPhotos = await PhotoScanService.collectGeoTaggedPhotos(
        onProgress:
            ({
              required int assetsProcessed,
              required int totalAssets,
              required int geoTagged,
            }) {
              if (!mounted) return;
              setState(() {
                _phaseProgress = totalAssets == 0 ? null : assetsProcessed / totalAssets;
                _statusLine =
                    'Finding geotagged photos… $geoTagged (${assetsProcessed.clamp(0, totalAssets)} / ${totalAssets == 0 ? '—' : '$totalAssets'})';
              });
            },
      );

      if (!mounted) return;

      if (geoPhotos.isEmpty) {
        setState(() {
          _countries = [];
          _scanning = false;
          _phaseProgress = null;
          _statusLine = '';
        });
        return;
      }

      setState(() {
        _phaseProgress = 0;
        _statusLine = 'Looking up places (${geoPhotos.length} photos)…';
      });

      final summaries = await _visitBuilder.buildFromPhotos(
        geoPhotos,
        onResolveProgress: ({required int done, required int total}) {
          if (!mounted) return;
          setState(() {
            _phaseProgress = total == 0 ? null : done / total;
            _statusLine = 'Looking up places… $done / $total';
          });
        },
      );

      if (!mounted) return;

      final scanResult = ScanResult(scannedAt: DateTime.now(), countries: summaries);
      await _cacheService.save(scanResult);

      if (!mounted) return;
      setState(() {
        _countries = summaries;
        _lastUpdated = scanResult.scannedAt;
        _scanning = false;
        _phaseProgress = null;
        _statusLine = '';
      });
    } catch (e, st) {
      debugPrint('$e\n$st');
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _phaseProgress = null;
        _statusLine = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ps = _permissionState;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roamly'),
        actions: [
          if (!_loadingPermission)
            IconButton(
              tooltip: ps?.hasAccess ?? false ? 'Scan again' : 'Scan or allow photos',
              onPressed: _scanning ? null : _runScan,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _loadingPermission
          ? const Center(child: CircularProgressIndicator())
          : _wrapLimitedBanner(
              ps,
              theme,
              _buildMain(ps, theme),
            ),
    );
  }

  Widget _wrapLimitedBanner(
    PermissionState? ps,
    ThemeData theme,
    Widget child,
  ) {
    final limited = ps?.isLimited ?? false;
    final show = limited && (ps?.hasAccess ?? false);
    if (!show) return child;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: theme.colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'Limited photo access — results include only the images you allowed.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildMain(PermissionState? ps, ThemeData theme) {
    if (_scanning) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _statusLine,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              if (_phaseProgress != null) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _phaseProgress),
              ],
            ],
          ),
        ),
      );
    }

    final hasAccess = ps?.hasAccess ?? false;
    final data = _countries;

    // Cached results are shown regardless of permission state — only scanning
    // again requires photo access.
    if (data == null) {
      if (!hasAccess) {
        return _NoPermissionTripsView(
          onAllowPhotos: _requestAccess,
          onOpenSettings: _openOsSettings,
        );
      }
      return _EmptyScanPrompt(onScan: _runScan);
    }

    if (data.isEmpty) {
      return _NoGeoPhotosPrompt(onRetry: _runScan);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_lastUpdated != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              _formatLastUpdated(_lastUpdated!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final country = data[index];
              return _CountryTile(country: country);
            },
          ),
        ),
      ],
    );
  }
}

class _NoPermissionTripsView extends StatelessWidget {
  const _NoPermissionTripsView({
    required this.onAllowPhotos,
    required this.onOpenSettings,
  });

  final VoidCallback onAllowPhotos;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Icon(
            Icons.map_outlined,
            size: 56,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No trips yet',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Roamly uses locations saved in your photos to build this list. Without photo access there is nothing to show here—you can still browse the app and turn on access whenever you like.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onAllowPhotos,
            child: const Text('Allow photo access'),
          ),
          TextButton(
            onPressed: onOpenSettings,
            child: const Text('Open system settings'),
          ),
        ],
      ),
    );
  }
}

class _EmptyScanPrompt extends StatelessWidget {
  const _EmptyScanPrompt({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.explore_outlined,
            size: 56,
            color: context.roamlyExtra.travelHighlight,
          ),
          const SizedBox(height: 16),
          Text(
            'See where you\'ve roamed',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Scan your library for photos that include a location. NYC appears only when photos are in one of the five NYC counties (the boroughs). New Jersey stays New Jersey.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onScan, child: const Text('Scan photo library')),
        ],
      ),
    );
  }
}

class _NoGeoPhotosPrompt extends StatelessWidget {
  const _NoGeoPhotosPrompt({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 56,
            color: context.roamlyExtra.secondaryUi,
          ),
          const SizedBox(height: 16),
          Text(
            'No locations found',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'None of your photos had embedded GPS coordinates. Turn on Save Location (or equivalent) in your camera app for future trips.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _CountryTile extends StatelessWidget {
  const _CountryTile({required this.country});

  final CountrySummary country;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = country.countryCode.toUpperCase();
    final avatar = code.length >= 2 ? code.substring(0, 2) : code;

    return ExpansionTile(
      key: PageStorageKey<String>('country-$code'),
      leading: CircleAvatar(
        backgroundColor: context.roamlyExtra.visitedMarker,
        foregroundColor: RoamlyPalette.deepSlate,
        child: Text(
          avatar,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      title: Text(country.countryName),
      subtitle: Text(
        '${country.cities.length} ${country.cities.length == 1 ? 'city' : 'cities'} · ${country.totalPhotos} photos',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      children: country.cities
          .map((c) => _CityTile(city: c, countryName: country.countryName))
          .toList(),
    );
  }
}

class _CityTile extends StatelessWidget {
  const _CityTile({required this.city, required this.countryName});

  final CitySummary city;
  final String countryName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
      child: Card(
        elevation: 0,
        color: Color.lerp(
          theme.colorScheme.surfaceContainerHighest,
          RoamlyPalette.softSand,
          0.25,
        ),
        child: ExpansionTile(
          title: Text(city.cityName),
          subtitle: Text(
            '${city.segments.length} ${city.segments.length == 1 ? 'stay' : 'stays'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          children: city.segments
              .map(
                (seg) => ListTile(
                  title: Text(formatVisitRange(seg.start, seg.end)),
                  subtitle: Text('${seg.photoCount} photos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VisitDetailScreen(
                        segment: seg,
                        cityName: city.cityName,
                        countryName: countryName,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

String _formatLastUpdated(DateTime dt) =>
    'Last updated ${DateFormat.yMMMd().add_jm().format(dt)}';
