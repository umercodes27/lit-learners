import 'package:flutter/material.dart';

import '../../core/routing/gentle_page_route.dart';
import '../../core/theme/age2_skin.dart';
import '../../models/activity_pack.dart';
import '../../services/content/activity_pack_loader.dart';
import '../../widgets/activities/age2_mascot.dart';
import '../../widgets/activities/playful_tap_target.dart';
import 'activity_levels_page.dart';

/// The age pack's front door: one big card per module, read straight from the
/// JSON.
///
/// Each card wears its own module's colour, which is the first place a child
/// meets the association — English is blue, Urdu is green — and the activity
/// screens behind it keep the same colour throughout.
class ActivityModulesPage extends StatefulWidget {
  const ActivityModulesPage({
    super.key,
    this.packPath = ActivityPackLoader.age2Path,
  });

  /// Which pack to show. Defaults to age 2, so every existing caller and route
  /// behaves exactly as before.
  final String packPath;

  @override
  State<ActivityModulesPage> createState() => _ActivityModulesPageState();
}

class _ActivityModulesPageState extends State<ActivityModulesPage> {
  late Future<ActivityPackLoadResult> _future;

  @override
  void initState() {
    super.initState();
    _future = ActivityPackLoader.forPath(widget.packPath)
        .load(path: widget.packPath);
  }

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
            child: FutureBuilder<ActivityPackLoadResult>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                final result = snapshot.data;
                final pack = result?.pack;
                if (result == null || pack == null) {
                  return _LoadFailure(message: result?.error ?? 'Unknown error');
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  children: [
                    const SizedBox(height: 6),
                    const Age2MascotBanner(
                      message: 'What shall we play today?',
                    ),
                    const SizedBox(height: 28),
                    if (result.hasRepairedAssets)
                      _ContentNotice(
                        icon: Icons.build_circle_outlined,
                        headline:
                            '${result.repairedAssets.length} path(s) pointed at the wrong folder',
                        detail:
                            'Matched by file name so they still show. Worth fixing in the JSON.',
                        lines: [
                          for (final entry in result.repairedAssets.entries)
                            '${entry.key}\n   → ${entry.value}',
                        ],
                      ),
                    if (result.hasMissingAssets)
                      _ContentNotice(
                        icon: Icons.warning_amber_rounded,
                        headline:
                            '${result.missingAssets.length} asset(s) referenced but not bundled',
                        detail: 'Those spots show a placeholder and stay playable.',
                        lines: result.missingAssets,
                      ),
                    for (final module in pack.modules)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _ModuleCard(
                          module: module,
                          onTap: () => Navigator.of(context).push(
                            GentlePageRoute<void>(
                              builder: (_) => ActivityLevelsPage(
                                args: ActivityLevelsArgs(
                                  module: module,
                                  pack: pack,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Carried to the levels screen so it does not have to reload the pack.
class ActivityLevelsArgs {
  const ActivityLevelsArgs({required this.module, required this.pack});

  final ActivityModule module;
  final ActivityPack pack;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.onTap});

  final ActivityModule module;
  final VoidCallback onTap;

  static const _icons = <String, IconData>{
    'english': Icons.abc_rounded,
    'urdu': Icons.translate_rounded,
    'math': Icons.calculate_rounded,
    'logic': Icons.extension_rounded,
    'storytelling': Icons.auto_stories_rounded,
  };

  @override
  Widget build(BuildContext context) {
    // Each card previews the colour of the module behind it.
    final palette = Age2Palette.forModule(module.key);
    final count = module.levels.length;

    return Age2Skin(
      palette: palette,
      child: PlayfulTapTarget(
        onTap: onTap,
        semanticLabel: module.title,
        background: palette.background,
        borderColor: palette.accent.withValues(alpha: 0.45),
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(
                _icons[module.key] ?? Icons.widgets_rounded,
                size: 46,
                color: palette.accent,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(module.title, style: Age2Text.titleFor(module.title)),
                  const SizedBox(height: 4),
                  Text(
                    count == 1 ? '1 thing to play' : '$count things to play',
                    style: Age2Text.label,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 42, color: palette.accent),
          ],
        ),
      ),
    );
  }
}

/// Content-authoring warnings.
///
/// Small, muted and set below the mascot: these are for whoever is testing the
/// pack, and must never be the loudest thing on a child's screen.
class _ContentNotice extends StatelessWidget {
  const _ContentNotice({
    required this.icon,
    required this.headline,
    required this.detail,
    required this.lines,
  });

  final IconData icon;
  final String headline;
  final String detail;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Age2Colors.sunflower, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Age2Colors.sunflower),
              const SizedBox(width: 8),
              Expanded(child: Text(headline, style: Age2Text.label)),
            ],
          ),
          const SizedBox(height: 6),
          Text(detail, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          for (final line in lines.take(10))
            Text('• $line', style: const TextStyle(fontSize: 11)),
          if (lines.length > 10)
            Text('• …and ${lines.length - 10} more',
                style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Age2Mascot(size: 110),
            const SizedBox(height: 20),
            const Text(
              'Nothing to play just yet',
              textAlign: TextAlign.center,
              style: Age2Text.cardTitle,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
