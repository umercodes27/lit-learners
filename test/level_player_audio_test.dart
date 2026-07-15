import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/learning_module.dart';
import 'package:little_learners/models/content_item.dart';
import 'package:little_learners/models/progress.dart';
import 'package:little_learners/repositories/content_repository.dart';
import 'package:little_learners/repositories/progress_repository.dart';
import 'package:little_learners/services/audio/koala_audio_player.dart';
import 'package:little_learners/viewmodels/active_child_session.dart';
import 'package:little_learners/viewmodels/learning_viewmodel.dart';
import 'package:little_learners/views/child_dashboard/level_player_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('LevelPlayerPage routes content audio cues through player',
      (tester) async {
    final audioPlayer = _FakeKoalaAudioPlayer();
    final level = _levelWithAudioCue();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ActiveChildSession()),
          ChangeNotifierProvider(
            create: (_) => LearningViewModel(
              contentRepository: _FakeContentRepository(level),
              progressRepository: _FakeProgressRepository(),
            ),
          ),
          Provider<KoalaAudioPlayer>.value(value: audioPlayer),
        ],
        child: const MaterialApp(
          home: LevelPlayerPage(levelId: 'english-letters'),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Play card audio'));
    await tester.pump();

    expect(audioPlayer.playedCueKeys, ['english_letter_a']);
    expect(audioPlayer.playedAssetBasePaths, ['audio/learning']);
  });
}

LearningLevel _levelWithAudioCue() {
  return const LearningLevel(
    id: 'english-letters',
    moduleId: 'english',
    stage: 3,
    levelNumber: 1,
    title: 'Letters',
    subtitle: 'Listen and say the letter.',
    type: LevelType.flashcards,
    passingScore: 70,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Letter A',
        prompt: 'Say A with Koala.',
        displayText: 'A',
        visualLabel: 'A says /a/',
        audioCueKey: 'english_letter_a',
      ),
    ],
  );
}

class _FakeContentRepository implements ContentRepository {
  const _FakeContentRepository(this.level);

  final LearningLevel level;

  @override
  Future<LearningLevel?> getLevelById(String levelId) async {
    return level.id == levelId ? level : null;
  }

  @override
  Future<LearningModule?> getModuleById(String moduleId) async => null;

  @override
  Future<List<LearningModule>> getModulesForStage(int stage) async => const [];

  @override
  Future<List<LearningLevel>> getLevelsForModule({
    required String moduleId,
    required int stage,
  }) async {
    return level.moduleId == moduleId && level.stage == stage ? [level] : [];
  }

  @override
  Future<void> markLevelDownloaded(String levelId) async {}
}

class _FakeProgressRepository implements ProgressRepository {
  @override
  Future<LevelProgress> completeLevel({
    required String childId,
    required LearningLevel level,
    int? score,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<LevelProgress>> getProgressForChild(String childId) async {
    return const [];
  }

  @override
  Future<LevelProgress?> getProgressForLevel({
    required String childId,
    required String levelId,
  }) async {
    return null;
  }

  @override
  Future<LevelProgress> recordVideoWatched({
    required String childId,
    required LearningLevel level,
    required String lessonId,
  }) async {
    throw UnimplementedError();
  }
}

class _FakeKoalaAudioPlayer implements KoalaAudioPlayer {
  final playedCueKeys = <String?>[];
  final playedAssetBasePaths = <String?>[];

  @override
  Future<KoalaAudioPlaybackResult> playCue(
    String? cueKey, {
    String? assetBasePath,
  }) async {
    playedCueKeys.add(cueKey);
    playedAssetBasePaths.add(assetBasePath);
    return KoalaAudioPlaybackResult(
      cueKey: cueKey,
      didPlay: true,
      source: KoalaAudioPlaybackSource.asset,
    );
  }
}
