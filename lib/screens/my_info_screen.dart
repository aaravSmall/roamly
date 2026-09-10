import 'package:flutter/material.dart';

import '../models/home_location.dart';
import '../models/visit_models.dart';
import '../services/home_candidates.dart';
import '../services/trip_stats.dart';
import '../theme/roamly_theme.dart';
import '../utils/date_range_format.dart';
import '../utils/distance.dart';
import 'home_confirm_screen.dart';

/// A stats overview of the user's travel history: home location plus
/// aggregate numbers (total trips, longest/farthest trip, most-visited
/// city/country) computed by [TripStats].
class MyInfoScreen extends StatelessWidget {
  const MyInfoScreen({
    super.key,
    required this.countries,
    required this.home,
    required this.onHomeChanged,
  });

  /// Post-home-filter results, owned by RoamlyShell. `null` means no scan
  /// has completed and no cache was found yet.
  final List<CountrySummary>? countries;
  final HomeLocation? home;
  final void Function(HomeLocation home) onHomeChanged;

  Future<void> _editHome(BuildContext context) async {
    final alternatives = homeCandidatesFromCountries(countries ?? const []);
    final candidate = home ?? (alternatives.isEmpty ? null : alternatives.first.home);
    if (candidate == null) return;

    final updated = await Navigator.of(context).push<HomeLocation>(
      MaterialPageRoute(
        builder: (_) => HomeConfirmScreen(candidate: candidate, alternatives: alternatives),
      ),
    );
    if (updated != null) onHomeChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final data = countries;

    return Scaffold(
      appBar: AppBar(title: const Text('My Info')),
      body: data == null
          ? _EmptyState(
              icon: Icons.insights_outlined,
              title: 'No stats yet',
              message: 'Scan your photo library from the Trips tab to see your travel stats here.',
            )
          : data.isEmpty
              ? _EmptyState(
                  icon: Icons.insights_outlined,
                  title: 'Nothing to show yet',
                  message: "We didn't find any trips in your last scan.",
                )
              : _StatsList(
                  countries: data,
                  home: home,
                  onEditHome: () => _editHome(context),
                ),
    );
  }
}

class _StatsList extends StatelessWidget {
  const _StatsList({required this.countries, required this.home, required this.onEditHome});

  final List<CountrySummary> countries;
  final HomeLocation? home;
  final VoidCallback onEditHome;

  @override
  Widget build(BuildContext context) {
    final stats = TripStats.compute(countries, home);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HomeTile(home: home, onTap: onEditHome),
        const SizedBox(height: 16),
        _StatTile(
          icon: Icons.card_travel,
          label: 'Total trips',
          value: '${stats.totalTrips}',
        ),
        _StatTile(
          icon: Icons.public,
          label: 'Countries / cities visited',
          value: '${stats.totalCountries} countries · ${stats.totalCities} cities',
        ),
        _StatTile(
          icon: Icons.calendar_month_outlined,
          label: 'Longest trip',
          value: stats.longestTrip == null ? '—' : _placeAndRange(stats.longestTrip!),
        ),
        _StatTile(
          icon: Icons.explore_outlined,
          label: 'Farthest trip',
          value: _farthestTripValue(stats),
        ),
        _StatTile(
          icon: Icons.flag_outlined,
          label: 'Most-visited country',
          value: stats.mostVisitedCountry == null
              ? '—'
              : '${stats.mostVisitedCountry!.countryName} — ${_tripCount(stats.mostVisitedCountry!)} trips',
        ),
        _StatTile(
          icon: Icons.location_city_outlined,
          label: 'Most-visited city',
          value: stats.mostVisitedCity == null ? '—' : _mostVisitedCityValue(stats.mostVisitedCity!),
        ),
      ],
    );
  }

  String _placeAndRange(VisitSegment segment) =>
      '${segment.place.cityDisplayName}, ${segment.place.countryName} — '
      '${formatVisitRange(segment.start, segment.end)}';

  String _mostVisitedCityValue(CitySummary city) {
    final countryName = city.segments.first.place.countryName;
    return '${city.cityName}, $countryName — ${city.segments.length} trips';
  }

  int _tripCount(CountrySummary country) =>
      country.cities.fold(0, (sum, c) => sum + c.segments.length);

  String _farthestTripValue(TripStats stats) {
    if (home == null) return 'Set your home to see this';
    final trip = stats.farthestTrip;
    if (trip == null) return '—';
    final miles = haversineMiles(
      home!.latitude,
      home!.longitude,
      trip.centroidLatitude!,
      trip.centroidLongitude!,
    );
    return '${trip.place.cityDisplayName}, ${trip.place.countryName} — '
        '${miles.toStringAsFixed(1)} mi';
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({required this.home, required this.onTap});

  final HomeLocation? home;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final home = this.home;

    return Card(
      child: ListTile(
        leading: Icon(Icons.home_outlined, color: context.roamlyExtra.travelHighlight),
        title: const Text('Home'),
        subtitle: Text(
          home == null
              ? 'Not set yet — tap to detect from your trips'
              : '${home.cityDisplayName}, ${home.countryName} · ${home.radiusMiles.round()} mi radius',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(icon, color: context.roamlyExtra.travelHighlight),
        title: Text(label),
        subtitle: Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

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
          Icon(icon, size: 56, color: context.roamlyExtra.secondaryUi),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
