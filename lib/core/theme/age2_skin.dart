import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../localization/urdu_letters.dart';

/// The look of the age-2 experience: pastel grounds, one warm accent per
/// module, and the rounded Fredoka face used for every word on screen.
///
/// Held in one place so the five modules read as one product rather than five
/// screens. A module only picks its [Age2Skin]; nothing downstream hard-codes a
/// colour, so re-tinting the whole age group is a change here and nowhere else.
///
/// Text colour stays [AppColors.ink] — a deep navy — on every pastel ground.
/// Pastels are light enough that a mid-tone label would fall below a readable
/// contrast, and toddlers are the last audience that should be squinting.
@immutable
class Age2Skin extends InheritedWidget {
  const Age2Skin({
    required this.palette,
    required super.child,
    super.key,
  });

  final Age2Palette palette;

  /// Falls back to the neutral palette so a widget can be dropped into a test
  /// or a preview without being wrapped first.
  static Age2Palette of(BuildContext context) {
    final skin = context.dependOnInheritedWidgetOfExactType<Age2Skin>();
    return skin?.palette ?? Age2Palette.neutral;
  }

  @override
  bool updateShouldNotify(Age2Skin oldWidget) => oldWidget.palette != palette;
}

@immutable
class Age2Palette {
  const Age2Palette({
    required this.background,
    required this.backgroundDeep,
    required this.accent,
    required this.surface,
  });

  /// Top of the page wash.
  final Color background;

  /// Bottom of the page wash — a hair deeper, so the screen has a soft
  /// horizon instead of a flat fill.
  final Color backgroundDeep;

  /// The module's signature colour: borders, the mascot ring, filled stars.
  final Color accent;

  /// Cards and tap targets sitting on the wash.
  final Color surface;

  static const neutral = Age2Palette(
    background: Age2Colors.cream,
    backgroundDeep: Age2Colors.butter,
    accent: Age2Colors.sunflower,
    surface: Colors.white,
  );

  static const english = Age2Palette(
    background: Age2Colors.skyMist,
    backgroundDeep: Age2Colors.sky,
    accent: Age2Colors.bluebird,
    surface: Colors.white,
  );

  static const urdu = Age2Palette(
    background: Age2Colors.mintMist,
    backgroundDeep: Age2Colors.mint,
    accent: Age2Colors.clover,
    surface: Colors.white,
  );

  static const math = Age2Palette(
    background: Age2Colors.cream,
    backgroundDeep: Age2Colors.peach,
    accent: Age2Colors.sunflower,
    surface: Colors.white,
  );

  static const logic = Age2Palette(
    background: Age2Colors.lilacMist,
    backgroundDeep: Age2Colors.lilac,
    accent: Age2Colors.grapeSoda,
    surface: Colors.white,
  );

  static const storytelling = Age2Palette(
    background: Age2Colors.blushMist,
    backgroundDeep: Age2Colors.blush,
    accent: Age2Colors.bubblegum,
    surface: Colors.white,
  );

  /// The palette for a module key from the content pack. Unknown modules get
  /// [neutral] rather than an error — a new module should look plain, not
  /// broken.
  static Age2Palette forModule(String? moduleKey) {
    return switch (moduleKey) {
      'english' => english,
      'urdu' => urdu,
      'math' => math,
      'logic' => logic,
      'storytelling' => storytelling,
      _ => neutral,
    };
  }

  LinearGradient get wash => LinearGradient(
        colors: [background, backgroundDeep],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  @override
  bool operator ==(Object other) =>
      other is Age2Palette &&
      other.background == background &&
      other.backgroundDeep == backgroundDeep &&
      other.accent == accent &&
      other.surface == surface;

  @override
  int get hashCode =>
      Object.hash(background, backgroundDeep, accent, surface);
}

/// Pastel grounds and the warm accents that sit on them.
class Age2Colors {
  const Age2Colors._();

  // Grounds — kept very light so ink-navy text stays high contrast.
  static const cream = Color(0xFFFFFBEF);
  static const butter = Color(0xFFFFF0C4);
  static const peach = Color(0xFFFFE3CC);
  static const skyMist = Color(0xFFF2FAFF);
  static const sky = Color(0xFFCFE9FF);
  static const mintMist = Color(0xFFF1FCF5);
  static const mint = Color(0xFFC8F2DA);
  static const blushMist = Color(0xFFFFF5F8);
  static const blush = Color(0xFFFFD9E6);
  static const lilacMist = Color(0xFFF8F4FF);
  static const lilac = Color(0xFFE2D5FF);

  // Accents — saturated enough to read as a border or a filled star.
  static const sunflower = Color(0xFFFFA928);
  static const bluebird = Color(0xFF3C91F4);
  static const clover = Color(0xFF22A875);
  static const grapeSoda = Color(0xFF8A63E8);
  static const bubblegum = Color(0xFFFF7DA8);
}

/// Type for the age-2 screens: Fredoka, large, and rounded.
///
/// Sizes start where most apps stop. Almost nothing here is read by the child
/// — the audio carries the instruction — so the few words on screen are for
/// the adult nearby and for recognition, and both are better served big.
class Age2Text {
  const Age2Text._();

  static const _family = 'Fredoka';

  static const screenTitle = TextStyle(
    fontFamily: _family,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    height: 1.15,
  );

  static const cardTitle = TextStyle(
    fontFamily: _family,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static const prompt = TextStyle(
    fontFamily: _family,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    height: 1.25,
  );

  static const label = TextStyle(
    fontFamily: _family,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.ink,
  );

  /// A single letter or numeral filling a tap target.
  static const glyph = TextStyle(
    fontFamily: _family,
    fontSize: 68,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    height: 1,
  );

  /// An Urdu letter filling a tap target.
  ///
  /// Nastaliq, not Fredoka — a Latin face has no Arabic glyphs and would fall
  /// back to whatever the platform happens to offer, which on the web is a
  /// different shape on every machine. The generous line height is not
  /// decorative: Nastaliq sits on a steep diagonal baseline and clips its own
  /// descenders at `height: 1`.
  static const urduGlyph = TextStyle(
    fontFamily: 'NotoNastaliqUrdu',
    fontSize: 58,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    height: 1.45,
  );

  /// A screen or card title written in Urdu.
  static const urduTitle = TextStyle(
    fontFamily: 'NotoNastaliqUrdu',
    fontSize: 26,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    height: 1.7,
  );

  /// The title style that suits [text] — Nastaliq for Urdu, Fredoka for the
  /// rest. Packs mix scripts, so the face has to follow the content rather
  /// than the module.
  static TextStyle titleFor(String text) =>
      UrduLetters.isUrduScript(text) ? urduTitle : screenTitle;

  /// As [titleFor], at card size.
  static TextStyle cardTitleFor(String text) => UrduLetters.isUrduScript(text)
      ? urduTitle.copyWith(fontSize: 22)
      : cardTitle;
}

/// Shared shape and shadow, so every pressable thing looks equally pressable.
class Age2Surfaces {
  const Age2Surfaces._();

  /// Nothing tappable is smaller than this. Well above the 48dp adult minimum:
  /// a two-year-old aims with a whole hand.
  static const minTapTarget = 96.0;

  static const cardRadius = Radius.circular(28);
  static BorderRadius get radius => const BorderRadius.all(cardRadius);

  static List<BoxShadow> lift({Color? tint}) => [
        BoxShadow(
          color: (tint ?? AppColors.ink).withValues(alpha: 0.16),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];
}
