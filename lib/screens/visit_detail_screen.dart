import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/visit_models.dart';
import '../theme/roamly_theme.dart';
import '../utils/date_range_format.dart';

class VisitDetailScreen extends StatelessWidget {
  const VisitDetailScreen({
    super.key,
    required this.segment,
    required this.cityName,
    required this.countryName,
  });

  final VisitSegment segment;
  final String cityName;
  final String countryName;

  @override
  Widget build(BuildContext context) {
    final dateRange = formatVisitRange(segment.start, segment.end);

    return Scaffold(
      appBar: AppBar(title: Text('$cityName, $countryName — $dateRange')),
      body: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: segment.photoIds.length,
        itemBuilder: (context, index) {
          return _VisitPhotoTile(
            photoId: segment.photoIds[index],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _PhotoViewerScreen(
                  photoIds: segment.photoIds,
                  initialIndex: index,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VisitPhotoTile extends StatefulWidget {
  const _VisitPhotoTile({required this.photoId, required this.onTap});

  final String photoId;
  final VoidCallback onTap;

  @override
  State<_VisitPhotoTile> createState() => _VisitPhotoTileState();
}

class _VisitPhotoTileState extends State<_VisitPhotoTile> {
  late final Future<Uint8List?> _thumbnailFuture = _loadThumbnail();

  Future<Uint8List?> _loadThumbnail() async {
    final asset = await AssetEntity.fromId(widget.photoId);
    if (asset == null) return null;
    return asset.thumbnailDataWithSize(const ThumbnailSize(300, 300));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('photo-tile-${widget.photoId}'),
      onTap: widget.onTap,
      child: FutureBuilder<Uint8List?>(
        future: _thumbnailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Container(color: context.roamlyExtra.secondaryUi);
          }
          final bytes = snapshot.data;
          if (bytes == null) {
            return _BrokenThumbnail(color: context.roamlyExtra.secondaryUi);
          }
          return Image.memory(bytes, fit: BoxFit.cover);
        },
      ),
    );
  }
}

class _BrokenThumbnail extends StatelessWidget {
  const _BrokenThumbnail({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _PhotoViewerScreen extends StatefulWidget {
  const _PhotoViewerScreen({required this.photoIds, required this.initialIndex});

  final List<String> photoIds;
  final int initialIndex;

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.photoIds.length,
            itemBuilder: (context, index) {
              return _FullPhotoPage(photoId: widget.photoIds[index]);
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullPhotoPage extends StatefulWidget {
  const _FullPhotoPage({required this.photoId});

  final String photoId;

  @override
  State<_FullPhotoPage> createState() => _FullPhotoPageState();
}

class _FullPhotoPageState extends State<_FullPhotoPage> {
  late final Future<Uint8List?> _imageFuture = _loadImage();

  Future<Uint8List?> _loadImage() async {
    final asset = await AssetEntity.fromId(widget.photoId);
    if (asset == null) return null;
    return asset.originBytes;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
          );
        }
        return InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
        );
      },
    );
  }
}
