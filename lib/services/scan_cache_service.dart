import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/scan_result.dart';

class ScanCacheService {
  static const String _fileName = 'roamly_cache.json';

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<ScanResult?> load() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      return ScanResult.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(ScanResult result) async {
    final file = await _cacheFile();
    await file.writeAsString(jsonEncode(result.toJson()));
  }

  Future<void> clear() async {
    final file = await _cacheFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
