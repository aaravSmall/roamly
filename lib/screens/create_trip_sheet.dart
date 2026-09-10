import 'package:country_state_city/country_state_city.dart' hide State;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/resolved_place.dart';
import '../models/visit_models.dart';
import '../services/world_map_country_names.dart';

String _countryNameForCode(String isoCode) =>
    kWorldMapCountryNames[isoCode.toLowerCase()] ?? isoCode;

String _displayForCity(City city) => '${city.name}, ${_countryNameForCode(city.countryCode)}';

/// The full ~148k-city offline dataset bundled by `country_state_city`, plus
/// derived lookup structures, loaded once per app session and reused across
/// every time the sheet is opened.
Future<(List<City>, List<String>, Map<String, City>)>? _citiesDataFuture;

Future<(List<City>, List<String>, Map<String, City>)> _loadCitiesData() {
  return _citiesDataFuture ??= getAllCities().then((cities) {
    final displayLower = List<String>.generate(
      cities.length,
      (i) => _displayForCity(cities[i]).toLowerCase(),
    );
    final byDisplay = <String, City>{
      for (var i = 0; i < cities.length; i++) displayLower[i]: cities[i],
    };
    return (cities, displayLower, byDisplay);
  });
}

/// Shows a modal bottom sheet form for adding a trip by hand (a single
/// "City, Country" field with real city+country autocomplete, plus a date
/// range), for trips that don't have geotagged photos to scan. Returns the
/// created [VisitSegment], or null if the sheet was dismissed.
Future<VisitSegment?> showCreateTripSheet(BuildContext context) {
  return showModalBottomSheet<VisitSegment>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _CreateTripSheet(),
  );
}

class _CreateTripSheet extends StatefulWidget {
  const _CreateTripSheet();

  @override
  State<_CreateTripSheet> createState() => _CreateTripSheetState();
}

class _CreateTripSheetState extends State<_CreateTripSheet> {
  final _locationController = TextEditingController();
  final _locationFocusNode = FocusNode();

  List<City> _cities = const [];
  List<String> _cityDisplayLower = const [];
  Map<String, City> _cityByDisplay = const {};
  bool _citiesLoading = true;

  DateTime? _start;
  DateTime? _end;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCitiesData().then((data) {
      if (!mounted) return;
      setState(() {
        _cities = data.$1;
        _cityDisplayLower = data.$2;
        _cityByDisplay = data.$3;
        _citiesLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    _locationFocusNode.dispose();
    super.dispose();
  }

  Iterable<City> _matchingCities(String query) sync* {
    for (var i = 0; i < _cities.length; i++) {
      if (_cityDisplayLower[i].contains(query)) yield _cities[i];
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _start : _end) ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        if (_end != null && _end!.isBefore(_start!)) _end = _start;
      } else {
        _end = picked;
        if (_start != null && _start!.isAfter(_end!)) _start = _end;
      }
    });
  }

  void _submit() {
    final city = _cityByDisplay[_locationController.text.trim().toLowerCase()];
    if (city == null || _start == null || _end == null) {
      setState(
        () => _error = city == null
            ? 'Pick a city from the suggestions.'
            : 'Choose both a start and end date.',
      );
      return;
    }

    Navigator.of(context).pop(
      VisitSegment(
        place: ResolvedPlace(
          countryCode: city.countryCode.toUpperCase(),
          countryName: _countryNameForCode(city.countryCode),
          cityDisplayName: city.name,
        ),
        start: _start!,
        end: _end!,
        photoCount: 0,
        photoIds: const [],
        manualId: '${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add a trip', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            Autocomplete<City>(
              textEditingController: _locationController,
              focusNode: _locationFocusNode,
              displayStringForOption: _displayForCity,
              optionsBuilder: (value) {
                final query = value.text.trim().toLowerCase();
                if (query.isEmpty) return const Iterable<City>.empty();
                return _matchingCities(query).take(30);
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'City, Country',
                    hintText: _citiesLoading ? 'Loading cities…' : 'e.g. Baku, Azerbaijan',
                  ),
                  onSubmitted: (_) => onFieldSubmitted(),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Start date',
                    value: _start == null ? null : dateFormat.format(_start!),
                    onTap: () => _pickDate(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'End date',
                    value: _end == null ? null : dateFormat.format(_end!),
                    onTap: () => _pickDate(isStart: false),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: const Text('Add trip')),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value ?? 'Select'),
      ),
    );
  }
}
