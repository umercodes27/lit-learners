import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/theme/app_theme.dart';
import 'package:little_learners/models/child_profile.dart';
import 'package:little_learners/repositories/content_repository.dart';
import 'package:little_learners/repositories/progress_repository.dart';
import 'package:little_learners/services/content/activity_pack_loader.dart';
import 'package:little_learners/services/content/activity_pack_stops.dart';
import 'package:little_learners/services/local/content_dao.dart';
import 'package:little_learners/viewmodels/active_child_session.dart';
import 'package:little_learners/viewmodels/learning_viewmodel.dart';
import 'package:little_learners/views/child_dashboard/module_levels_page.dart';
import 'package:little_learners/views/child_dashboard/widgets/level_map.dart';
import 'package:provider/provider.dart';

// The seeded ladder now only shows for subjects with no age-pack counterpart,
// so these exercise it through Tracing. Subjects that do have a pack are
// covered by the last test here.
void main() {
  testWidgets('the levels screen names the portion each level covers',
      (tester) async {
    final errors = _captureLayoutErrors();
    addTearDown(errors.restore);

    await _pump(tester);
    errors.restore();

    // The ladder a child climbs, visible without opening anything.
    expect(find.text('Trace a b c'), findsOneWidget);
    expect(find.text('Trace 4 5 6'), findsOneWidget);
    expect(errors.details, isEmpty);
  });

  testWidgets('the portion chip counts the steps inside the level',
      (tester) async {
    await _pump(tester);

    // Note the first level is labelled `a – c` but seeds four letters, a – d.
    // The chip reports what the level actually holds.
    expect(find.textContaining('a – c  ·  4 steps'), findsOneWidget);
    expect(find.textContaining('4 – 6  ·  3 steps'), findsOneWidget);
  });

  testWidgets('only the first level is open until it is finished',
      (tester) async {
    await _pump(tester);

    // Level 1 is open; the levels above it are covered by a lock whose
    // tooltip says why.
    expect(find.byIcon(Icons.lock), findsNWidgets(2));
    expect(
      find.byTooltip('Finish the previous level first.'),
      findsNWidgets(2),
    );
  });

  testWidgets('a subject with pack activities shows no seeded ladder',
      (tester) async {
    await _pump(tester, moduleId: 'english');

    // English is served by the age pack, so the seeded ladder - its portion
    // chips, its downloads - stays out of the way rather than repeating the
    // subject in a second, slower form. (Locking is not one of the
    // differences: a pack road unlocks in sequence too, covered below.)
    expect(find.textContaining('steps'), findsNothing);
    expect(find.text('Download'), findsNothing);

    // What replaces it: the pack's own activities, walked as stops on the same
    // map the seeded ladder uses. The profile is three, so this is the age-3
    // pack rather than age 2.
    expect(find.text('Tracing Letters A-M'), findsOneWidget);
    expect(find.text('Drag & Match'), findsOneWidget);

    // A pack stop says what the child will be doing where a seeded one says
    // its portion and step count.
    expect(find.text('Trace the shape'), findsNWidgets(2));
    expect(find.text('Drag to match'), findsOneWidget);

    // The module quiz is the trophy at the end of the road.
    expect(find.bySemanticsLabel('Finish with a quiz'), findsOneWidget);
  });

  testWidgets('a pack road starts with only its first stop open',
      (tester) async {
    await _pump(tester, moduleId: 'english');

    // Same sequence the seeded ladder walks: stop one is open, the two behind
    // it wait for it. Three English activities in the age-3 pack.
    expect(find.byType(MapProgressBar), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsNWidgets(2));
    expect(
      find.byTooltip(ActivityPackStops.lockReason),
      findsNWidgets(2),
    );
  });

  testWidgets('finishing a pack activity moves the road on', (tester) async {
    final learning = await _pump(tester, moduleId: 'english');

    // Stand in for playing the activity through: this is the level the screen
    // records against when ActivityLevelPage pops `true`.
    const path = ActivityPackLoader.age3Path;
    final pack = (await ActivityPackLoader.forPath(path).load(path: path)).pack!;
    final first = ActivityPackStops.forModule(
      pack.moduleByKey('english')!,
      moduleId: 'english',
      stage: 2,
      isCompleted: (_) => false,
      starsFor: (_) => 0,
    ).first;

    await learning.completeLevel(_profile.id, first.level);
    await tester.pumpAndSettle();

    // The stop behind the child is done, and the one that was locked is now
    // the open one - which is what moves the highlight and fills the road.
    expect(find.byIcon(Icons.lock), findsNWidgets(1));
  });
}

Future<LearningViewModel> _pump(
  WidgetTester tester, {
  String moduleId = 'tracing',
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final learning = LearningViewModel(
    contentRepository: CachedContentRepository(
      contentDao: InMemoryContentDao(),
    ),
    progressRepository: InMemoryProgressRepository(),
  );
  await learning.loadForProfile(_profile);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LearningViewModel>.value(value: learning),
        ChangeNotifierProvider<ActiveChildSession>(
          create: (_) => ActiveChildSession()..selectProfile(_profile),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: ModuleLevelsPage(moduleId: moduleId),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return learning;
}

_LayoutErrorCapture _captureLayoutErrors() {
  final capture = _LayoutErrorCapture(FlutterError.onError);
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) {
      capture.details.add(details);
    } else {
      capture.original?.call(details);
    }
  };
  return capture;
}

class _LayoutErrorCapture {
  _LayoutErrorCapture(this.original);

  final void Function(FlutterErrorDetails)? original;
  final details = <FlutterErrorDetails>[];
  bool _restored = false;

  void restore() {
    if (_restored) return;
    FlutterError.onError = original;
    _restored = true;
  }
}

final _profile = ChildProfile(
  id: 'child-1',
  parentId: 'parent-1',
  name: 'Ali',
  age: 3,
  avatarAsset: 'koala-blue',
  leaderboardOptIn: false,
  displayPreference: 'firstName',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  isSynced: true,
);
