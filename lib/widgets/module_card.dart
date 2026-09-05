import 'package:flutter/material.dart';

import '../core/utils/learning_text_direction.dart';
import '../core/utils/module_visuals.dart';
import '../models/learning_module.dart';
import 'play/play.dart';

/// A module, as a solid block of its own colour.
///
/// It used to be a white panel with a faint wash of the module colour behind
/// it and a hairline border — which meant eight modules read as eight nearly
/// identical white rectangles. For a child who cannot read the titles, colour
/// and the glyph are the only things telling them apart, so both are now the
/// whole card: the tile *is* the colour, and the icon is enormous.
///
/// Flat fill, no gradient. A solid slab reads as an object to press.
class ModuleCard extends StatelessWidget {
  const ModuleCard({
    required this.module,
    required this.onTap,
    super.key,
  });

  final LearningModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = PlayColors.forCategory(module.category);
    final textDirection = LearningTextDirection.forModule(module);

    return Squishy(
      semanticLabel: 'Open ${module.title}',
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(PlayMotion.radiusLarge),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: PlayColors.ink.withValues(alpha: 0.22),
              offset: const Offset(0, 7),
              blurRadius: 0,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Flat cut-out shapes rather than a gradient wash.
            Positioned(
              right: -26,
              top: -30,
              child: _Blob(
                size: 92,
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              left: -18,
              bottom: -24,
              child: _Blob(
                size: 62,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // The glyph carries the whole card for a pre-reader, so it
                  // gets the room a description used to take.
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Icon(
                        ModuleVisuals.iconFor(module.category),
                        color: Colors.white,
                        size: 96,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Directionality(
                    textDirection: textDirection,
                    child: Text(
                      module.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: LearningTextDirection.styleFor(
                        const TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 21,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textDirection,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
