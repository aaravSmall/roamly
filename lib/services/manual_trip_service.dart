import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/visit_models.dart';

/// Persists trips added by hand (via the "Add trip" form) separately from
/// [ScanCacheService]'s photo-derived [ScanResult], so they survive both app
/// restarts and re-scans of the photo library.
class ManualTripService {
  static const String _fileName = 'roamly_manual_trips.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<VisitSegment>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (json['segments'] as List<dynamic>)
          .map((e) => VisitSegment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<VisitSegment> segments) async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode({'segments': segments.map((s) => s.toJson()).toList()}),
    );
  }
}
