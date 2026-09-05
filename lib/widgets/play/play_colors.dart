import 'package:flutter/material.dart';

import '../../models/learning_module.dart';

/// The child app's colour, and it is loud on purpose.
///
/// `AppColors` is a grown-up palette — soft violet, hairline grey, white
/// panels — and it stays exactly as it is for the parent dashboard and the
/// admin portal, which are read by adults. It is the wrong palette for a
/// one to four year old, and reusing it is what made the first pass at this
/// look like the same app in a new coat.
///
/// Two rules hold this together:
///
/// * **Flat colour, no gradients.** A gradient is a grown-up device. Toddler
///   things — blocks, crayons, stacking cups — are solid colour, and solid
///   colour is what reads at that age.
/// * **A screen is a colour, not a white page with colour on it.** Every child
///   screen gets a ground, and the content sits on it in white cards.
class PlayColors {
  const PlayColors._();

  // Grounds and accents. Saturated, high-contrast, and deliberately closer to
  // a box of crayons than to a design system.
  static const sunshine = Color(0xFFFFD23F);
  static const tangerine = Color(0xFFFF8C42);
  static const strawberry = Color(0xFFFF5C7A);
  static const bubblegum = Color(0xFFFF6FB5);
  static const grape = Color(0xFF9B5DE5);
  static const blueberry = Color(0xFF3D8BFF);
  static const sky = Color(0xFF32C5FF);
  static const mint = Color(0xFF23D5AB);
  static const grass = Color(0xFF4CCD5B);
  static const lime = Color(0xFFB8E62E);

  /// Text and outlines. Warm near-black rather than pure black, which is
  /// harsh next to this much saturation.
  static const ink = Color(0xFF2B2145);

  /// Cards sit on the ground in white or cream, never in grey.
  static const card = Color(0xFFFFFFFF);
  static const cream = Color(0xFFFFF7E8);

  /// Every ground, for screens that want to pick one by index.
  static const grounds = <Color>[
    blueberry,
    strawberry,
    grass,
    grape,
    tangerine,
    mint,
    bubblegum,
    sky,
  ];

  /// A module's colour on child screens.
  ///
  /// Deliberately brighter than `ModuleVisuals.colorFor`, which the parent and
  /// admin screens keep using — the same module reads as a calmer colour in a
  /// progress report than it does on a toddler's home screen, which is right.
  static Color forCategory(ModuleCategory category) {
    return switch (category) {
      ModuleCategory.english => blueberry,
      ModuleCategory.math => grass,
      ModuleCategory.urdu => grape,
      ModuleCategory.logic => tangerine,
      ModuleCategory.story => strawberry,
      ModuleCategory.drawing => mint,
      ModuleCategory.tracing => sky,
      ModuleCategory.video => bubblegum,
    };
  }

  static Color forModuleId(String moduleId) {
    for (final category in ModuleCategory.values) {
      if (category.name == moduleId) return forCategory(category);
    }
    return blueberry;
  }

  /// A stable bright colour for anything without a module of its own — a
  /// level tile, an avatar, a list row.
  static Color byIndex(int index) {
    return grounds[index.abs() % grounds.length];
  }

  /// Text that sits on a coloured ground.
  static Color onGround(Color ground) {
    return ThemeData.estimateBrightnessForColor(ground) == Brightness.dark
        ? Colors.white
        : ink;
  }
}
