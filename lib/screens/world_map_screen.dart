import 'package:countries_world_map/countries_world_map.dart';
import 'package:countries_world_map/data/maps/world_map.dart';
import 'package:flutter/material.dart';

import '../models/visit_models.dart';
import '../services/country_map_codes.dart';
import '../services/world_map_country_names.dart';
import '../theme/roamly_theme.dart';

class WorldMapScreen extends StatelessWidget {
  const WorldMapScreen({super.key, required this.countries});

  final List<CountrySummary> countries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visitedById = <String, CountrySummary>{
      for (final country in countries)
        worldMapCountryId(country.countryCode): country,
    };
    final colors = <String, Color>{
      for (final id in visitedById.keys) id: context.roamlyExtra.visitedMarker,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('World Map')),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 8,
          child: SimpleMap(
            instructions: SMapWorld.instructionsMercator,
            defaultColor: RoamlyPalette.lightGray,
            countryBorder: CountryBorder(color: theme.colorScheme.surface),
            colors: colors,
            callback: (id, name, tapDetails) {
              _showCountrySheet(context, id: id, visitedById: visitedById);
            },
          ),
        ),
      ),
    );
  }

  void _showCountrySheet(
    BuildContext context, {
    required String id,
    required Map<String, CountrySummary> visitedById,
  }) async {
    final country = visitedById[id];
    final displayName = kWorldMapCountryNames[id] ?? id.toUpperCase();

    final viewTrips = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _CountrySheet(
        name: displayName,
        country: country,
        onViewTrips: () => Navigator.of(sheetContext).pop(true),
      ),
    );

    if (viewTrips == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _CountrySheet extends StatelessWidget {
  const _CountrySheet({
    required this.name,
    required this.country,
    required this.onViewTrips,
  });

  final String name;
  final CountrySummary? country;
  final VoidCallback onViewTrips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visited = country;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: theme.textTheme.headlineSmall),
            if (visited != null) ...[
              const SizedBox(height: 8),
              Text(
                '${visited.cities.length} ${visited.cities.length == 1 ? 'city' : 'cities'} · '
                '${visited.totalPhotos} photos',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onViewTrips,
                child: const Text('View trips'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
