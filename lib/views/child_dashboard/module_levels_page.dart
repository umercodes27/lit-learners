import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/gentle_page_route.dart';
import '../../core/routing/route_names.dart';
import '../../core/utils/age_stage_helper.dart';
import '../../core/utils/learning_text_direction.dart';
import '../../core/utils/module_visuals.dart';
import '../../models/activity_pack.dart';
import '../../models/koala_guide_message.dart';
import '../../models/learning_level.dart';
import '../../models/module_quiz.dart';
import '../../services/content/activity_pack_loader.dart';
import '../../services/content/activity_pack_stops.dart';
import '../../services/content/module_activity_bridge.dart';
import '../../services/content/module_quiz_builder.dart';
import '../../viewmodels/active_child_session.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../../services/audio/app_sounds.dart';
import '../../services/audio/sound_controller.dart';
import '../../widgets/koala_guide.dart';
import '../../widgets/play/play.dart';
import '../activity_pack/activity_level_page.dart';
import 'module_quiz_page.dart';
import 'widgets/level_map.dart';

/// A module's levels, as a map a child walks rather than a list they scroll.
///
/// This started as a `ListView` of Material `Card`s, then became a column of
/// numbered rows. Both were still a list: four things stacked up, with nothing
/// saying where the child is or how far there is to go.
///
/// It is now a road. The stops are joined by a winding path, the part already
/// walked is filled in behind them, and there is a trophy at the end. Every
/// module gets a different road, derived from its id — see [MapShape].
///
/// Two content systems feed that road. Subjects the age packs cover — English,
/// Urdu, Maths, Logic, Story — walk the pack for the active child's age, and
/// their trophy is the module's quiz. Everything else — Drawing, Tracing,
/// Video — walks the seeded ladder as before. A child meets one road either
/// way and never learns there were two systems.
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

  /// Set while the trophy celebration is on screen, after the module quiz is
  /// passed. The road behind it stays visible: the point is to see the trophy
  /// land on the map you just walked.
  bool _celebratingTrophy = false;

  @override
  void initState() {
    super.initState();
    AppSound.instance.playMusic(MusicTrack.home);
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
    final ground = PlayColors.forModuleId(widget.moduleId);
    final textDirection = module == null
        ? TextDirection.ltr
        : LearningTextDirection.forModule(module);

    final packFuture = _packFuture;

    return Scaffold(
      body: Stack(
        children: [
          PlayGround(
            color: ground,
            safeArea: false,
            child: SafeArea(
          child: packFuture == null
              ? _seededMap(context, learning, module, child, textDirection)
              : FutureBuilder<ActivityPackLoadResult>(
                  future: packFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return _shell(
                        module: module,
                        textDirection: textDirection,
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      );
                    }

                    final packModule = _packModuleFrom(snapshot.data);
                    // A pack that failed to load, or has nothing for this
                    // subject, falls back to the seeded ladder rather than
                    // stranding the child on an empty road.
                    if (packModule == null) {
                      return _seededMap(
                        context,
                        learning,
                        module,
                        child,
                        textDirection,
                      );
                    }

                    return _packMap(
                      context: context,
                      learning: learning,
                      packModule: packModule,
                      pack: snapshot.data!.pack!,
                      module: module,
                      child: child,
                      textDirection: textDirection,
                    );
                  },
                ),
            ),
          ),
          if (_celebratingTrophy)
            _TrophyCelebration(
              moduleTitle: module?.title ?? 'this subject',
              accent: ground,
              onDone: () => setState(() => _celebratingTrophy = false),
            ),
        ],
      ),
    );
  }

  /// Opens the module quiz and celebrates on the map if it is passed.
  ///
  /// The quiz has its own trophy screen, but that one is inside the quiz — a
  /// child taps Done and lands back on a road that looks exactly as it did
  /// before. The celebration belongs here too, over the map they just
  /// finished, which is the thing the trophy is attached to.
  Future<void> _openTrophyQuiz(ModuleQuiz quiz, Color accent) async {
    final passed = await Navigator.of(context).push<bool>(
      GentlePageRoute<bool>(
        builder: (_) => ModuleQuizPage(quiz: quiz, accent: accent),
      ),
    );

    if (!mounted || passed != true) return;
    AppSound.instance.play(Sfx.moduleComplete);
    setState(() => _celebratingTrophy = true);
  }

  ActivityModule? _packModuleFrom(ActivityPackLoadResult? result) {
    final pack = result?.pack;
    if (pack == null) return null;
    final key = ModuleActivityBridge.packModuleKeyFor(widget.moduleId);
    if (key == null) return null;
    final packModule = pack.moduleByKey(key);
    if (packModule == null || packModule.levels.isEmpty) return null;
    return packModule;
  }

  /// The chrome every version of this screen shares: the header, and a
  /// scrolling body under it.
  Widget _shell({
    required dynamic module,
    required TextDirection textDirection,
    required Widget child,
    Widget? underHeader,
  }) {
    return Column(
      children: [
        PlayHeader(
          title: module?.title ?? 'Levels',
          textDirection: textDirection,
          titleStyle: LearningTextDirection.styleFor(
            const TextStyle(),
            textDirection,
          ),
          onBack: () => Navigator.of(context).maybePop(),
        ),
        if (underHeader != null) underHeader,
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: child,
          ),
        ),
      ],
    );
  }

  Widget _guide({
    required dynamic module,
    required dynamic child,
    required TextDirection textDirection,
  }) {
    return ContextualKoalaGuide(
      trigger: KoalaGuideTrigger.moduleIntro,
      audience: KoalaGuideAudience.child,
      moduleId: widget.moduleId,
      stage: child == null ? null : AgeStageHelper.stageForAge(child.age),
      textDirection: textDirection,
      fallbackMessage: module?.description ??
          'Choose a level and try one short activity.',
    );
  }

  /// The seeded ladder, unchanged: real levels, real progress, real locks.
  Widget _seededMap(
    BuildContext context,
    LearningViewModel learning,
    dynamic module,
    dynamic child,
    TextDirection textDirection,
  ) {
    final levels = learning.levelsFor(widget.moduleId);
    final stops = [
      for (final level in levels)
        LevelStopData(
          level: level,
          stars: learning.starsFor(level.id),
          completed: learning.isLevelCompleted(level.id),
          canOpen: learning.canOpenLevel(level),
          canDownload: learning.canDownloadLevel(level),
          lockReason: learning.lockReasonFor(level),
        ),
    ];
    final done = stops.where((stop) => stop.completed).length;

    return _shell(
      module: module,
      textDirection: textDirection,
      underHeader: stops.isEmpty
          ? null
          : MapProgressBar(done: done, total: stops.length),
      child: Column(
        children: [
          _guide(module: module, child: child, textDirection: textDirection),
          const SizedBox(height: 12),
          LevelMap(
            stops: stops,
            moduleId: widget.moduleId,
            accent: PlayColors.sunshine,
            textDirection: textDirection,
            onOpen: (level) => _openLevel(context, level),
            onDownload: (level) => _download(context, level),
            onLocked: (reason) => _showLocked(context, reason),
          ),
        ],
      ),
    );
  }

  /// The same road, walked over age-pack activities.
  ///
  /// A finished activity is recorded against its drawn level's id, so the road
  /// fills in, the highlight moves to the next stop and the bar counts up
  /// exactly as they do for the seeded ladder.
  Widget _packMap({
    required BuildContext context,
    required LearningViewModel learning,
    required ActivityModule packModule,
    required ActivityPack pack,
    required dynamic module,
    required dynamic child,
    required TextDirection textDirection,
  }) {
    final stage = child == null ? 1 : AgeStageHelper.stageForAge(child.age);
    final stops = ActivityPackStops.forModule(
      packModule,
      moduleId: widget.moduleId,
      stage: stage,
      isCompleted: learning.isLevelCompleted,
      starsFor: learning.starsFor,
    );
    final done = stops.where((stop) => stop.completed).length;
    final quiz = ModuleQuizBuilder.build(packModule);
    final accent = ModuleVisuals.colorForModuleId(widget.moduleId);

    // Levels are addressed by their sort order, which is what the adapter
    // numbered the stops by.
    final ordered = [...packModule.levels]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return _shell(
      module: module,
      textDirection: textDirection,
      underHeader: stops.isEmpty
          ? null
          : MapProgressBar(done: done, total: stops.length),
      child: Column(
        children: [
          _guide(module: module, child: child, textDirection: textDirection),
          const SizedBox(height: 12),
          LevelMap(
            stops: stops,
            moduleId: widget.moduleId,
            accent: PlayColors.sunshine,
            textDirection: textDirection,
            onOpen: (level) => _openPackLevel(
              context,
              level,
              ordered[level.levelNumber - 1],
              pack,
            ),
            // Nothing in a pack is downloaded separately - the whole pack
            // ships in the bundle - so this cannot fire. It is required.
            onDownload: (_) {},
            onLocked: (reason) => _showLocked(context, reason),
            // The quiz is the trophy at the end of the road. A module whose
            // activities cannot produce enough questions shows no quiz at all
            // — see [ModuleQuizBuilder] — and the trophy stays decoration.
            onGoalTap:
                quiz.isEmpty ? null : () => _openTrophyQuiz(quiz, accent),
            goalLabel: quiz.isEmpty ? null : 'Finish with a quiz',
          ),
        ],
      ),
    );
  }

  /// Opens one pack activity, and records it if the child plays it through.
  ///
  /// [drawn] is the level the map drew for this stop; its id is what progress
  /// is written against, so the road behind the child fills in on the way
  /// back. Backing out of the activity pops without a result and records
  /// nothing.
  Future<void> _openPackLevel(
    BuildContext context,
    LearningLevel drawn,
    ActivityLevel level,
    ActivityPack pack,
  ) async {
    if (level.data.isEmpty) {
      _showLocked(context, 'This one is coming soon.');
      return;
    }

    final childId = context.read<ActiveChildSession>().activeChild?.id;
    final learning = context.read<LearningViewModel>();

    final finished = await Navigator.of(context).push<bool>(
      GentlePageRoute<bool>(
        builder: (_) => ActivityLevelPage(
          args: ActivityLevelArgs(
            level: level,
            correctSound: level.data.correctSound ?? pack.correctSound,
            wrongSound: level.data.wrongSound ?? pack.wrongSound,
          ),
        ),
      ),
    );

    if (finished != true || childId == null) return;
    // No score: a pack activity is played to the end rather than marked, and
    // an unscored completion earns its three stars. See [CachedProgressRepository].
    await learning.completeLevel(childId, drawn);
  }

  void _openLevel(BuildContext context, LearningLevel level) {
    Navigator.of(context)
        .pushNamed(RouteNames.levelPlayer, arguments: level.id);
  }

  void _showLocked(BuildContext context, String reason) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
  }

  Future<void> _download(BuildContext context, LearningLevel level) async {
    await context.read<LearningViewModel>().downloadLevel(level);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${level.title} downloaded.')),
    );
  }
}


/// The trophy landing on the map the child just finished.
///
/// Shown over the road rather than as another page: the reward is that *this*
/// map is complete, and pushing a fresh screen would hide the thing being
/// rewarded. Taps through to dismiss, and clears itself after a few seconds so
/// a child who puts the phone down does not come back to a stuck overlay.
class _TrophyCelebration extends StatefulWidget {
  const _TrophyCelebration({
    required this.moduleTitle,
    required this.accent,
    required this.onDone,
  });

  final String moduleTitle;
  final Color accent;
  final VoidCallback onDone;

  @override
  State<_TrophyCelebration> createState() => _TrophyCelebrationState();
}

class _TrophyCelebrationState extends State<_TrophyCelebration> {
  Timer? _dismiss;

  @override
  void initState() {
    super.initState();
    _dismiss = Timer(const Duration(milliseconds: 4200), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _dismiss?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: widget.onDone,
        child: ColoredBox(
          color: PlayColors.ink.withValues(alpha: 0.45),
          child: Stack(
            children: [
              Center(
                child: PopIn(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: PlayPanel(
                      padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.emoji_events_rounded,
                            size: 92,
                            color: PlayColors.sunshine,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Trophy won!',
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: PlayColors.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You finished ${widget.moduleTitle}.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 18,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: PlayColors.ink.withValues(alpha: 0.75),
                            ),
                          ),
                          const SizedBox(height: 22),
                          PlayButton(
                            label: 'Yay!',
                            icon: Icons.celebration_rounded,
                            color: widget.accent,
                            onPressed: widget.onDone,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: IgnorePointer(child: ConfettiBurst(pieces: 46)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
