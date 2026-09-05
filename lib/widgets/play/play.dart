/// The play kit: the child-facing app's shared visual and motion vocabulary.
///
/// One import gives a screen everything it needs to feel like a toy rather
/// than a form:
///
/// ```dart
/// import '../../widgets/play/play.dart';
/// ```
///
/// Built for ages 1-4, which drives every decision in here: touch targets far
/// above the adult Material minimum, corners far rounder than the grown-up
/// screens, saturated flat colour, and a physical reaction to every touch.
///
/// Two standing rules:
///
/// * **No gradients on child screens.** Flat colour reads at this age; a
///   gradient is a grown-up device.
/// * **Restyle by editing these files, not by adding one-off decorations to a
///   screen.** Scattered per-screen values are exactly what this replaced on
///   the admin side.
library;

export 'confetti_burst.dart';
export 'jelly_card.dart';
export 'play_button.dart';
export 'play_choice.dart';
export 'play_field.dart';
export 'play_colors.dart';
export 'play_dialog.dart';
export 'play_ground.dart';
export 'play_header.dart';
export 'play_motion.dart';
export 'play_route.dart';
export 'popping_stars.dart';
export 'pop_in.dart';
export 'squishy.dart';
