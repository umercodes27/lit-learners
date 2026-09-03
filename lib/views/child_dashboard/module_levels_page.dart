import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/gentle_page_route.dart';
import '../../core/routing/route_names.dart';
import '../../core/utils/activity_component_visuals.dart';
import '../../core/utils/age_stage_helper.dart';
import '../../core/utils/learning_text_direction.dart';
import '../../core/utils/module_visuals.dart';
import '../../models/activity_pack.dart';
import '../../models/koala_guide_message.dart';
import '../../models/learning_level.dart';
import '../../models/module_quiz.dart';
import '../../services/content/activity_pack_loader.dart';
import '../../services/content/module_activity_bridge.dart';
import '../../services/content/module_quiz_builder.dart';
import '../../viewmodels/active_child_session.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../../widgets/koala_guide.dart';
import '../../widgets/locked_overlay.dart';
import '../../widgets/star_rating.dart';
import '../activity_pack/activity_level_page.dart';
import 'module_quiz_page.dart';

/// Everything the app has for one subject, in one list.
///
/// Two content systems feed this screen. The age packs come from a bundled
/// JSON and are ready to play the moment they are tapped; the level ladder
/// comes from the seeded content tree and carries stars, downloads and
/// unlocking. They are shown as two labelled sections rather than merged,
/// because only one of them has a progression to respect - but a child
/// arriving from the dashboard finds both under the subject they picked,
/// which is the point.
class ModuleLevelsPage extends StatefulWidget {
  const ModuleLevelsPage({
    required this.moduleId,
    super.key,
  });

  final String moduleId;

  @override
  State<ModuleLevelsPage> createState() => _ModuleLevelsPageState();
}

class _ModuleLevelsPageState extends State<ModuleLevelsPage> {
  Future<ActivityPackLoadResult>? _packFuture;
  int? _packAge;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LearningViewModel>().loadLevelsForModule(widget.moduleId);
    });
  }

  /// Picks the pack once the active child is known, and again if the child
  /// changes underneath us. Modules with no age-pack counterpart never load
  /// one, so Video and Drawing keep exactly the screen they had.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!ModuleActivityBridge.hasActivities(widget.moduleId)) return;

    final age = context.read<ActiveChildSession>().activeChild?.age ?? 3;
    final packAge = ModuleActivityBridge.packAgeFor(age);
    if (packAge == _packAge) return;

    final path = ModuleActivityBridge.packPathFor(age);
    _packAge = packAge;
    _packFuture = ActivityPackLoader.forPath(path).load(path: path);
  }

  @override
  Widget build(BuildContext context) {
    final learning = context.watch<LearningViewModel>();
    final child = context.watch<ActiveChildSession>().activeChild;
    final module = learning.moduleById(widget.moduleId);
    final levels = learning.levelsFor(widget.moduleId);
    final textDirection = module == null
        ? TextDirection.ltr
        : LearningTextDirection.forModule(module);
    final learningTextStyle = LearningTextDirection.styleFor(
      null,
      textDirection,
    );
    final accent = ModuleVisuals.colorForModuleId(widget.moduleId);
    final packFuture = _packFuture;
    final packAge = _packAge;
    final hasPack = ModuleActivityBridge.hasActivities(widget.moduleId);

    return Scaffold(
      appBar: AppBar(
        title: Directionality(
          textDirection: textDirection,
          child: Text(
            module?.title ?? 'Levels',
            style: learningTextStyle,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ContextualKoalaGuide(
              trigger: KoalaGuideTrigger.moduleIntro,
              audience: KoalaGuideAudience.child,
              moduleId: widget.moduleId,
              stage: child == null
                  ? null
                  : AgeStageHelper.stageForAge(child.age),
              textDirection: textDirection,
              fallbackMessage: module?.description ??
                  'Choose a level and try one short activity.',
            ),
            if (packFuture != null && packAge != null)
              _ActivityPackSection(
                future: packFuture,
                moduleId: widget.moduleId,
                packAge: packAge,
                accent: accent,
              ),
            // The seeded ladder is a fallback, not a second section. A subject
            // that has age-pack activities shows those alone - the ladder
            // repeated the same subject in a second, slower form. Drawing and
            // Tracing have no pack counterpart, so they keep the ladder rather
            // than open to an empty screen.
            if (!hasPack)
              for (final level in levels)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _seedLevelTile(learning, level, textDirection),
                ),
          ],
        ),
      ),
    );
  }

  /// One rung of the seeded ladder, unchanged: same lock rules, same download
  /// button, same stars, same route.
  Widget _seedLevelTile(
    LearningViewModel learning,
    LearningLevel level,
    TextDirection textDirection,
  ) {
    final canOpen = learning.canOpenLevel(level);
    final canDownload = learning.canDownloadLevel(level);
    final reason = learning.lockReasonFor(level);

    return Stack(
      children: [
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(
              child: Text(level.levelNumber.toString()),
            ),
            title: Directionality(
              textDirection: textDirection,
              child: Text(
                level.title,
                textAlign: LearningTextDirection.alignFor(textDirection),
                style: LearningTextDirection.styleFor(null, textDirection),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: textDirection == TextDirection.rtl
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                _PortionChip(
                  portionLabel: level.portionLabel,
                  stepCount: level.contentItems.length,
                  accent: ModuleVisuals.colorForModuleId(level.moduleId),
                ),
                const SizedBox(height: 6),
                Directionality(
                  textDirection: textDirection,
                  child: Text(
                    level.subtitle,
                    textAlign: LearningTextDirection.alignFor(textDirection),
                    style: LearningTextDirection.styleFor(null, textDirection),
                  ),
                ),
                if (canDownload) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await context
                          .read<LearningViewModel>()
                          .downloadLevel(level);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${level.title} downloaded.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                  ),
                ],
              ],
            ),
            trailing: StarRating(count: learning.starsFor(level.id)),
            onTap: () {
              if (!canOpen) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(reason)),
                );
                return;
              }
              Navigator.of(context).pushNamed(
                RouteNames.levelPlayer,
                arguments: level.id,
              );
            },
          ),
        ),
        if (!canOpen && !canDownload) LockedOverlay(reason: reason),
      ],
    );
  }
}

/// The age-pack activities for this subject.
///
/// Nothing here is gated. The packs are a tap-and-listen curriculum with no
/// prerequisite chain, and a locked card is only a wall between a two-year-old
/// and the one activity they wanted. A pack that fails to load simply leaves
/// the section out, and the ladder below it still works.
class _ActivityPackSection extends StatelessWidget {
  const _ActivityPackSection({
    required this.future,
    required this.moduleId,
    required this.packAge,
    required this.accent,
  });

  final Future<ActivityPackLoadResult> future;
  final String moduleId;
  final int packAge;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final packKey = ModuleActivityBridge.packModuleKeyFor(moduleId);
    if (packKey == null) return const SizedBox.shrink();

    return FutureBuilder<ActivityPackLoadResult>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final pack = snapshot.data?.pack;
        final levels =
            pack?.moduleByKey(packKey)?.levels ?? const <ActivityLevel>[];
        if (pack == null || levels.isEmpty) return const SizedBox.shrink();

        final module = pack.moduleByKey(packKey)!;
        final quiz = ModuleQuizBuilder.build(module);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            _SectionHeading(
              label: 'Play now',
              detail: 'Age $packAge, sound on',
              accent: accent,
            ),
            for (final level in levels)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _ActivityLevelCard(
                  level: level,
                  pack: pack,
                  accent: accent,
                ),
              ),
            // The quiz closes the module, so it sits below every activity it
            // draws its questions from.
            if (!quiz.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: _ModuleQuizCard(quiz: quiz, accent: accent),
              ),
          ],
        );
      },
    );
  }
}

/// One playable pack activity, styled to sit in the same list as the ladder
/// cards above it while still reading as a different kind of thing: a filled
/// accent tile for the icon, and no level number, because the pack has no
/// order to keep.
class _ActivityLevelCard extends StatelessWidget {
  const _ActivityLevelCard({
    required this.level,
    required this.pack,
    required this.accent,
  });

  final ActivityLevel level;
  final ActivityPack pack;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final component = level.data.component;
    final playable = !level.data.isEmpty;
    final titleDirection = LearningTextDirection.forText(level.title);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        enabled: playable,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            ActivityComponentVisuals.iconFor(component),
            color: accent,
            size: 26,
          ),
        ),
        title: Directionality(
          textDirection: titleDirection,
          child: Text(
            level.title,
            textAlign: LearningTextDirection.alignFor(titleDirection),
            style: LearningTextDirection.styleForText(
              const TextStyle(fontWeight: FontWeight.w700),
              level.title,
            ),
          ),
        ),
        subtitle: Text(
          playable
              ? ActivityComponentVisuals.labelFor(component)
              : 'Coming soon',
        ),
        trailing: Icon(
          playable
              ? Icons.play_circle_fill_rounded
              : Icons.hourglass_empty_rounded,
          color: accent,
          size: 34,
        ),
        onTap: playable
            ? () => Navigator.of(context).push(
                  GentlePageRoute<void>(
                    builder: (_) => ActivityLevelPage(
                      args: ActivityLevelArgs(
                        level: level,
                        correctSound:
                            level.data.correctSound ?? pack.correctSound,
                        wrongSound: level.data.wrongSound ?? pack.wrongSound,
                      ),
                    ),
                  ),
                )
            : null,
      ),
    );
  }
}

/// The way in to the module's closing quiz.
///
/// Styled unlike the activity cards on purpose - filled in the subject's
/// colour rather than white - so it reads as the end of the module rather than
/// one more thing to play.
class _ModuleQuizCard extends StatelessWidget {
  const _ModuleQuizCard({required this.quiz, required this.accent});

  final ModuleQuiz quiz;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent.withValues(alpha: 0.12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: accent.withValues(alpha: 0.45), width: 2),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          GentlePageRoute<bool>(
            builder: (_) => ModuleQuizPage(quiz: quiz, accent: accent),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: accent, size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Module quiz',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${quiz.length} questions  ·  pass at '
                      '${ModuleQuiz.passingPercent}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Names a run of cards, so the two content systems below read as a deliberate
/// pairing rather than one list that changes shape halfway down.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.label,
    required this.detail,
    required this.accent,
  });

  final String label;
  final String detail;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              detail,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ink.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Names the slice of the module a level covers, so a parent scanning the list
/// can see the ladder - `A - F`, then `G - L` - rather than only level numbers.
class _PortionChip extends StatelessWidget {
  const _PortionChip({
    required this.portionLabel,
    required this.stepCount,
    required this.accent,
  });

  final String? portionLabel;
  final int stepCount;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final steps = stepCount == 1 ? '1 step' : '$stepCount steps';
    // Modules that are not a sequence (Story, Drawing) carry no portion, so
    // the chip falls back to how much there is to work through.
    final label = portionLabel == null ? steps : '$portionLabel  ·  $steps';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Color.alphaBlend(
            accent.withValues(alpha: 0.85),
            AppColors.ink,
          ),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
