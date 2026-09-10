import 'package:flutter/material.dart';

import '../models/home_location.dart';
import '../services/home_location_service.dart';
import '../theme/roamly_theme.dart';

/// Shown the first time a home is auto-detected (from the scan flow), and
/// reopened later (e.g. from My Info) to change home or radius. Always
/// saves via [HomeLocationService] before popping — pops with the newly
/// confirmed [HomeLocation], or null if dismissed without confirming.
class HomeConfirmScreen extends StatefulWidget {
  const HomeConfirmScreen({
    super.key,
    required this.candidate,
    required this.alternatives,
  });

  /// The home to show pre-selected (the auto-detected top guess, or the
  /// currently-saved home when reopened from My Info).
  final HomeLocation candidate;

  /// Every other city already seen in the library, with photo counts, for
  /// the "Not quite" picker — most-photographed first (includes
  /// [candidate] itself, since callers don't need to filter it out).
  final List<({HomeLocation home, int photoCount})> alternatives;

  @override
  State<HomeConfirmScreen> createState() => _HomeConfirmScreenState();
}

class _HomeConfirmScreenState extends State<HomeConfirmScreen> {
  final _homeLocationService = HomeLocationService();
  late HomeLocation _selected = widget.candidate;
  late final _radiusController = TextEditingController(
    text: widget.candidate.radiusMiles.round().toString(),
  );
  bool _saving = false;

  @override
  void dispose() {
    _radiusController.dispose();
    super.dispose();
  }

  double get _radius => double.tryParse(_radiusController.text) ?? widget.candidate.radiusMiles;

  Future<void> _confirm(HomeLocation home) async {
    setState(() => _saving = true);
    final confirmed = HomeLocation(
      countryCode: home.countryCode,
      countryName: home.countryName,
      cityDisplayName: home.cityDisplayName,
      latitude: home.latitude,
      longitude: home.longitude,
      radiusMiles: _radius,
      confirmed: true,
    );
    await _homeLocationService.save(confirmed);
    if (!mounted) return;
    Navigator.of(context).pop(confirmed);
  }

  Future<void> _pickDifferentCity() async {
    final picked = await showModalBottomSheet<HomeLocation>(
      context: context,
      showDragHandle: true,
      builder: (_) => _CityPickerSheet(alternatives: widget.alternatives),
    );
    if (picked != null) setState(() => _selected = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = _radius.round();

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm your home')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.home_outlined,
                size: 56,
                color: context.roamlyExtra.travelHighlight,
              ),
              const SizedBox(height: 16),
              Text(
                'We think your home is around ${_selected.cityDisplayName}, ${_selected.countryName}.',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                "Photos within $radius miles of here won't count as trips.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _radiusController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Radius (miles)'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : () => _confirm(_selected),
                child: const Text('Looks right'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _saving || widget.alternatives.length <= 1 ? null : _pickDifferentCity,
                child: const Text("Not quite — pick a different city"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CityPickerSheet extends StatelessWidget {
  const _CityPickerSheet({required this.alternatives});

  final List<({HomeLocation home, int photoCount})> alternatives;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: alternatives.length,
        itemBuilder: (context, index) {
          final alt = alternatives[index];
          return ListTile(
            title: Text('${alt.home.cityDisplayName}, ${alt.home.countryName}'),
            subtitle: Text('${alt.photoCount} photos'),
            onTap: () => Navigator.of(context).pop(alt.home),
          );
        },
      ),
    );
  }
}
