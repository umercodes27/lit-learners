import 'package:flutter/material.dart';

import 'play/play.dart';

/// A picture an admin attached to a card or a quiz question.
///
/// Pictures come from the network, so everything that can go wrong with the
/// network is handled here rather than in front of a child: while it loads
/// the space is held so nothing jumps, and if it fails the widget collapses
/// to nothing — the card's own words still say what it is.
class ContentImage extends StatelessWidget {
  const ContentImage({
    super.key,
    required this.url,
    this.maxHeight = 220,
  });

  final String url;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PlayMotion.radius),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const ColoredBox(
                color: Color(0x14000000),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
