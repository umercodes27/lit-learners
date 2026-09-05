import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/content/asset_availability.dart';

/// An image from a content pack that cannot take the screen down.
///
/// Packs reference art that may not have been drawn yet. [Image.asset] throws
/// during build for a path the bundle does not have, so this checks the
/// manifest first and falls back to a labelled placeholder — the activity
/// stays playable and the gap is visible to whoever is testing it, instead of
/// a red error box or a silent blank.
class ActivityAssetImage extends StatelessWidget {
  const ActivityAssetImage({
    required this.path,
    super.key,
    this.size,
    this.fit = BoxFit.contain,
    this.silhouette = false,
  });

  final String? path;
  final double? size;
  final BoxFit fit;

  /// Renders the image as a flat dark shape. The shadow-match round needs
  /// silhouettes, and painting them keeps the art directory half the size.
  final bool silhouette;

  @override
  Widget build(BuildContext context) {
    final resolved = path;
    if (resolved == null || !AssetAvailability.instance.has(resolved)) {
      return _MissingAsset(path: resolved, size: size);
    }

    final image = Image.asset(
      resolved,
      width: size,
      height: size,
      fit: fit,
      // Belt and braces: the manifest can still disagree with the bundle on
      // web after a partial rebuild.
      errorBuilder: (context, error, stack) =>
          _MissingAsset(path: resolved, size: size),
    );

    if (!silhouette) return image;

    return ColorFiltered(
      colorFilter: const ColorFilter.mode(AppColors.grape, BlendMode.srcIn),
      child: image,
    );
  }
}

class _MissingAsset extends StatelessWidget {
  const _MissingAsset({required this.path, this.size});

  final String? path;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final name = path == null ? 'no asset' : path!.split('/').last;
    return Container(
      width: size,
      height: size,
      constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
      decoration: BoxDecoration(
        color: AppColors.lemon,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.honey, width: 2),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_not_supported_outlined,
              color: AppColors.ink, size: 22),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
