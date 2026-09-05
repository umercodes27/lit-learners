import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/theme/app_theme.dart';
import 'package:little_learners/models/child_profile.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/learning_module.dart';
import 'package:little_learners/models/quiz_question.dart';
import 'package:little_learners/models/video_lesson.dart';
import 'package:little_learners/repositories/content_repository.dart';
import 'package:little_learners/repositories/progress_repository.dart';
import 'package:little_learners/services/local/content_dao.dart';
import 'package:little_learners/viewmodels/active_child_session.dart';
import 'package:little_learners/viewmodels/learning_viewmodel.dart';
import 'package:little_learners/views/video/video_learning_page.dart';
import 'package:little_learners/widgets/play/play.dart';
import 'package:provider/provider.dart';

void main() {
  // Video levels that ship undownloaded had no way to be fetched: the page drew
  // a locked overlay over the card and offered no Download button, so the next
  // level stayed unreachable even after the previous one was passed.
  testWidgets('an undownloaded video level offers a download button',
      (tester) async {
    final learning = await _learning();
    await _pump(tester, learning);

    expect(find.text('Watch and Count'), findsOneWidget);
    expect(find.text('Shapes in Motion'), findsOneWidget);
    expect(find.widgetWithText(PlayButton, 'Download'), findsOneWidget);
  });

  testWidgets('downloading unlocks the level for playing', (tester) async {
    final learning = await _learning();
    await _pump(tester, learning);

    final locked = learning
        .levelsFor('video')
        .firstWhere((level) => level.id == 'video-stage3-2');
    expect(learning.canOpenLevel(locked), isFalse);
    expect(learning.canDownloadLevel(locked), isTrue);

    // The levels are a map now, so a stop further along the road can sit
    // below the fold. Scroll to it the way a parent would before tapping.
    await tester.ensureVisible(find.widgetWithText(PlayButton, 'Download'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PlayButton, 'Download'));
    await tester.pumpAndSettle();

    final unlocked = learning
        .levelsFor('video')
        .firstWhere((level) => level.id == 'video-stage3-2');
    expect(learning.canOpenLevel(unlocked), isTrue);
    expect(find.widgetWithText(PlayButton, 'Download'), findsNothing);
  });

  testWidgets('a level behind an unfinished one stays locked', (tester) async {
    final learning = await _learning(completeFirstLevel: false);
    await _pump(tester, learning);

    final second = learning
        .levelsFor('video')
        .firstWhere((level) => level.id == 'video-stage3-2');

    expect(learning.canDownloadLevel(second), isFalse);
    expect(learning.lockReasonFor(second), 'Finish the previous level first.');
    expect(find.widgetWithText(PlayButton, 'Download'), findsNothing);
  });
}

Future<LearningViewModel> _learning({bool completeFirstLevel = true}) async {
  final progressRepository = InMemoryProgressRepository();
  final learning = LearningViewModel(
    contentRepository: CachedContentRepository(
      contentDao: InMemoryContentDao(),
      bundledModules: const [_videoModule],
      bundledLevels: const [_firstLevel, _secondLevel],
      contentRevision: 'test',
    ),
    progressRepository: progressRepository,
  );

  if (completeFirstLevel) {
    await progressRepository.completeLevel(
      childId: 'child-1',
      level: _firstLevel,
      score: 90,
    );
  }

  await learning.loadForProfile(_profile);
  await learning.loadLevelsForModule('video');
  return learning;
}

Future<void> _pump(WidgetTester tester, LearningViewModel learning) async {
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
        home: const VideoLearningPage(moduleId: 'video'),
      ),
    ),
  );
  await tester.pumpAndSettle();
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

const _videoModule = LearningModule(
  id: 'video',
  title: 'Video Learning',
  description: 'Short guided lessons.',
  category: ModuleCategory.video,
  minStage: 1,
  maxStage: 4,
  order: 4,
);

const _firstLevel = LearningLevel(
  id: 'video-stage3-1',
  moduleId: 'video',
  stage: 3,
  levelNumber: 1,
  title: 'Watch and Count',
  subtitle: 'A short counting video.',
  type: LevelType.video,
  passingScore: 70,
  isBundled: true,
  videoLessons: [
    VideoLesson(
      id: 'count-video-1',
      title: 'Counting Bees',
      description: 'Count along.',
      durationLabel: '0:30',
      videoUrl: 'https://example.com/a.mp4',
      thumbnailLabel: 'Counting video',
    ),
  ],
  quizQuestions: [
    QuizQuestion(
      id: 'video-count-q1',
      prompt: 'What did you watch?',
      options: ['A bee', 'A car'],
      correctIndex: 0,
    ),
  ],
);

const _secondLevel = LearningLevel(
  id: 'video-stage3-2',
  moduleId: 'video',
  stage: 3,
  levelNumber: 2,
  title: 'Shapes in Motion',
  subtitle: 'Watch simple shapes move.',
  type: LevelType.video,
  passingScore: 70,
  isBundled: false,
  videoLessons: [
    VideoLesson(
      id: 'shapes-video-1',
      title: 'Shape Parade',
      description: 'Circle, square, triangle.',
      durationLabel: '0:20',
      videoUrl: 'https://example.com/b.mp4',
      thumbnailLabel: 'Shape video',
    ),
  ],
);
