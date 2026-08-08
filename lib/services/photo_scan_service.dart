import 'dart:math';

import 'package:photo_manager/photo_manager.dart';

import '../models/geo_photo.dart';

typedef ScanProgress =
    void Function({
      required int assetsProcessed,
      required int totalAssets,
      required int geoTagged,
    });

class PhotoScanService {
  static const int batchSize = 250;

  static Future<List<GeoPhoto>> collectGeoTaggedPhotos({
    ScanProgress? onProgress,
  }) async {
    final filter = FilterOptionGroup(imageOption: const FilterOption());

    final totalCount = await PhotoManager.getAssetCount(
      filterOption: filter,
      type: RequestType.image,
    );

    final result = <GeoPhoto>[];

    for (var start = 0; start < totalCount; start += batchSize) {
      final end = min(start + batchSize, totalCount);
      final batch = await PhotoManager.getAssetListRange(
        start: start,
        end: end,
        filterOption: filter,
        type: RequestType.image,
      );

      for (final asset in batch) {
        LatLng? ll = asset.latLng;
        ll ??= await asset.latlngAsync();
        if (ll == null) continue;

        result.add(
          GeoPhoto(
            assetId: asset.id,
            takenAt: asset.createDateTime,
            lat: ll.latitude,
            lng: ll.longitude,
          ),
        );
      }

      onProgress?.call(
        assetsProcessed: end,
        totalAssets: totalCount,
        geoTagged: result.length,
      );
    }

    return result;
  }
}
