import 'package:flutter/material.dart';

import '../../core/routing/gentle_page_route.dart';
import '../../core/theme/age2_skin.dart';
import '../../services/content/activity_pack_loader.dart';
import '../../widgets/activities/age2_mascot.dart';
import '../../widgets/activities/playful_tap_target.dart';
import 'activity_modules_page.dart';

/// One age pack the app ships.
@immutable
class AgePack {
  const AgePack({
    required this.age,
    required this.path,
    required this.blurb,
    required this.palette,
  });

  final int age;
  final String path;

  /// A word or two for the adult choosing. The child navigates by the number.
  final String blurb;
  final Age2Palette palette;

  static const all = <AgePack>[
    AgePack(
      age: 2,
      path: ActivityPackLoader.age2Path,
      blurb: 'Tap, listen and match',
      palette: Age2Palette.math,
    ),
    AgePack(
      age: 3,
      path: ActivityPackLoader.age3Path,
      blurb: 'Drag, sort and trace',
      palette: Age2Palette.logic,
    ),
    AgePack(
      age: 4,
      path: ActivityPackLoader.age4Path,
      blurb: 'Build words, add and solve',
      palette: Age2Palette.storytelling,
    ),
  ];
}

/// Choose an age group.
///
/// Both packs ship together, so this is the way in. It exists because a pack
/// is content rather than a build flavour — adding age 4 means another JSON
/// and one entry in [AgePack.all].
class ActivityAgePickerPage extends StatelessWidget {
  const ActivityAgePickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    const palette = Age2Palette.neutral;

    return Age2Skin(
      palette: palette,
      child: Scaffold(
        backgroundColor: palette.background,
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: palette.wash),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                const Age2MascotBanner(message: 'How old are you?'),
                const SizedBox(height: 30),
                for (final pack in AgePack.all)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _AgeCard(
                      pack: pack,
                      onTap: () => Navigator.of(context).push(
                        GentlePageRoute<void>(
                          builder: (_) =>
                              ActivityModulesPage(packPath: pack.path),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgeCard extends StatelessWidget {
  const _AgeCard({required this.pack, required this.onTap});

  final AgePack pack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Age2Skin(
      palette: pack.palette,
      child: PlayfulTapTarget(
        onTap: onTap,
        semanticLabel: 'Age ${pack.age}',
        background: pack.palette.background,
        borderColor: pack.palette.accent.withValues(alpha: 0.45),
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              width: 92,
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Text(
                '${pack.age}',
                style: Age2Text.glyph.copyWith(color: pack.palette.accent),
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Age ${pack.age}', style: Age2Text.screenTitle),
                  const SizedBox(height: 4),
                  Text(pack.blurb, style: Age2Text.label),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 42, color: pack.palette.accent),
          ],
        ),
      ),
    );
  }
}
