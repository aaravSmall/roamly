import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/home_location.dart';

/// Persists the detected/confirmed home location, separate from
/// [ScanCacheService]'s scan results.
class HomeLocationService {
  static const String _fileName = 'home_location.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<HomeLocation?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      return HomeLocation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(HomeLocation home) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(home.toJson()));
  }

  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
