import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';

import '../photo_permission.dart';
import '../theme/roamly_theme.dart';
import '../models/geo_photo.dart';
import '../models/home_location.dart';
import '../models/scan_result.dart';
import '../models/visit_models.dart';
import '../services/home_candidates.dart';
import '../services/home_detector.dart';
import '../services/home_location_service.dart';
import '../services/photo_scan_service.dart';
import '../services/scan_cache_service.dart';
import '../services/trip_filter.dart';
import '../services/visit_builder.dart';
import '../utils/date_range_format.dart';
import 'create_trip_sheet.dart';
import 'home_confirm_screen.dart';
import 'visit_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.countries,
    required this.lastScannedAt,
    required this.totalPhotosAnalyzed,
    required this.home,
    required this.onResultsChanged,
    required this.onHomeChanged,
    required this.onManualTripAdded,
    required this.onDeleteManualTrip,
    this.focusCountryCode,
    this.onFocusHandled,
  });

  /// Current results, owned by RoamlyShell so the Trips and Map tabs stay in
  /// sync. `null` means no scan has completed and no cache was found yet.
  final List<CountrySummary>? countries;
  final DateTime? lastScannedAt;

  /// Geotagged photos considered in the last scan, before the home-radius
  /// filter excluded any of them — for the "N photos analyzed" stat line.
  final int? totalPhotosAnalyzed;

  /// The confirmed (or still-just-detected) home location, owned by
  /// RoamlyShell so every screen sees the same one.
  final HomeLocation? home;

  /// Called after a scan completes with everything RoamlyShell needs to
  /// persist and share: the built trip tree, when the scan ran, how many
  /// geotagged photos were considered, and the fully-resolved (unfiltered)
  /// photo list — kept in memory so a later home change can re-filter
  /// without a full re-scan.
  final void Function({
    required List<CountrySummary> countries,
    required DateTime scannedAt,
    required int totalPhotosAnalyzed,
    required List<TaggedPhoto> taggedPhotos,
  }) onResultsChanged;

  /// Called whenever a home is detected/confirmed/changed from this screen.
  final void Function(HomeLocation home) onHomeChanged;

  /// Called with a new [VisitSegment] (`isManual == true`) when the user
  /// submits the "Add trip" form.
  final void Function(VisitSegment segment) onManualTripAdded;

  /// Called with a manually-added segment's [VisitSegment.manualId] when the
  /// user removes it.
  final void Function(String manualId) onDeleteManualTrip;

  /// Country code to auto-expand and scroll into view (e.g. after tapping
  /// "View trips" on the World Map). Consumed once, then [onFocusHandled]
  /// is called to clear it.
  final String? focusCountryCode;
  final VoidCallback? onFocusHandled;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  PermissionState? _permissionState;

  bool _loadingPermission = true;
  bool _scanning = false;
  String _statusLine = '';

  double? _phaseProgress;

  final VisitBuilder _visitBuilder = VisitBuilder();
  final ScanCacheService _cacheService = ScanCacheService();
  final HomeLocationService _homeLocationService = HomeLocationService();

  final Map<String, GlobalKey> _countryTileKeys = {};
  final Map<String, ExpansibleController> _countryTileControllers = {};

  GlobalKey _keyFor(String countryCode) =>
      _countryTileKeys.putIfAbsent(countryCode, () => GlobalKey());

  ExpansibleController _controllerFor(String countryCode) =>
      _countryTileControllers.putIfAbsent(countryCode, () => ExpansibleController());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncPermission();
    if (widget.focusCountryCode != null) {
      _scheduleFocus(widget.focusCountryCode!);
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusCountryCode != null &&
        widget.focusCountryCode != oldWidget.focusCountryCode) {
      _scheduleFocus(widget.focusCountryCode!);
    }
  }

  void _scheduleFocus(String countryCode) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _countryTileControllers[countryCode]?.expand();
      final tileContext = _countryTileKeys[countryCode]?.currentContext;
      if (tileContext != null) {
        Scrollable.ensureVisible(
          tileContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.05,
        );
      }
      widget.onFocusHandled?.call();
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
        widget.onResultsChanged(
          countries: const [],
          scannedAt: DateTime.now(),
          totalPhotosAnalyzed: 0,
          taggedPhotos: const [],
        );
        if (!mounted) return;
        setState(() {
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

      final taggedPhotos = await _visitBuilder.resolvePhotos(
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

      final home = await _resolveHome(taggedPhotos);
      if (!mounted) return;

      final filtered = filterOutHomeRadius(taggedPhotos, home);
      final summaries = VisitBuilder.buildFromTagged(filtered);

      final scanResult = ScanResult(
        scannedAt: DateTime.now(),
        countries: summaries,
        totalPhotosAnalyzed: geoPhotos.length,
      );
      await _cacheService.save(scanResult);
      if (!mounted) return;

      widget.onResultsChanged(
        countries: summaries,
        scannedAt: scanResult.scannedAt,
        totalPhotosAnalyzed: scanResult.totalPhotosAnalyzed,
        taggedPhotos: taggedPhotos,
      );
      if (!mounted) return;
      setState(() {
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

  /// Loads the saved home if there is one (a saved home is always
  /// confirmed, so it's used as-is — no silent re-detection/overwrite).
  /// Otherwise runs [HomeDetector] on this scan's photos and asks the user
  /// to confirm it via [HomeConfirmScreen] before continuing. Returns null
  /// if there's no home yet and the user dismisses the prompt without
  /// confirming one.
  Future<HomeLocation?> _resolveHome(List<TaggedPhoto> taggedPhotos) async {
    final saved = await _homeLocationService.load();
    if (saved != null) return saved;

    final candidate = HomeDetector().detectHome(taggedPhotos);
    if (candidate == null) return null;

    // A throwaway (unfiltered) summary tree, used only to list every city
    // already seen as alternatives in the confirm screen's city picker.
    final unfiltered = VisitBuilder.buildFromTagged(taggedPhotos);
    final alternatives = homeCandidatesFromCountries(unfiltered);

    if (!mounted) return null;
    final confirmed = await Navigator.of(context).push<HomeLocation>(
      MaterialPageRoute(
        builder: (_) => HomeConfirmScreen(candidate: candidate, alternatives: alternatives),
      ),
    );
    if (confirmed != null) widget.onHomeChanged(confirmed);
    return confirmed;
  }

  Future<void> _addTrip() async {
    final segment = await showCreateTripSheet(context);
    if (segment != null) widget.onManualTripAdded(segment);
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
      floatingActionButton: _scanning
          ? null
          : FloatingActionButton(
              tooltip: 'Add trip',
              onPressed: _addTrip,
              child: const Icon(Icons.add),
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
    final data = widget.countries;

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
        if (widget.lastScannedAt != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              _formatLastUpdated(widget.lastScannedAt!, widget.totalPhotosAnalyzed),
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
              return _CountryTile(
                key: _keyFor(country.countryCode),
                country: country,
                controller: _controllerFor(country.countryCode),
                onDeleteManualTrip: widget.onDeleteManualTrip,
              );
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
  const _CountryTile({
    super.key,
    required this.country,
    required this.controller,
    required this.onDeleteManualTrip,
  });

  final CountrySummary country;
  final ExpansibleController controller;
  final void Function(String manualId) onDeleteManualTrip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = country.countryCode.toUpperCase();
    final avatar = code.length >= 2 ? code.substring(0, 2) : code;

    return ExpansionTile(
      controller: controller,
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
          .map(
            (c) => _CityTile(
              city: c,
              countryName: country.countryName,
              onDeleteManualTrip: onDeleteManualTrip,
            ),
          )
          .toList(),
    );
  }
}

class _CityTile extends StatelessWidget {
  const _CityTile({
    required this.city,
    required this.countryName,
    required this.onDeleteManualTrip,
  });

  final CitySummary city;
  final String countryName;
  final void Function(String manualId) onDeleteManualTrip;

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
                (seg) => seg.isManual
                    ? ListTile(
                        title: Text(formatVisitRange(seg.start, seg.end)),
                        subtitle: const Text('Added manually'),
                        trailing: IconButton(
                          tooltip: 'Remove trip',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => onDeleteManualTrip(seg.manualId!),
                        ),
                      )
                    : ListTile(
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

String _formatLastUpdated(DateTime dt, int? totalPhotosAnalyzed) {
  final base = 'Last updated ${DateFormat.yMMMd().add_jm().format(dt)}';
  if (totalPhotosAnalyzed == null) return base;
  return '$base · $totalPhotosAnalyzed photos analyzed';
}
