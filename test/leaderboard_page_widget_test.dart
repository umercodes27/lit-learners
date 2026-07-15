import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/theme/app_theme.dart';
import 'package:little_learners/models/leaderboard_entry.dart';
import 'package:little_learners/views/leaderboard/leaderboard_page.dart';

void main() {
  testWidgets('LeaderboardPanel fits narrow rows without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final previousOnError = FlutterError.onError;
    final flutterErrors = <FlutterErrorDetails>[];
    FlutterError.onError = flutterErrors.add;
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: LeaderboardPanel(
            entries: [
              _entry(
                rank: 1,
                displayName: 'Learner With A Very Long Display Name',
              ),
              _entry(
                rank: 2,
                displayName: 'Another Very Long Learner Alias',
              ),
              _entry(
                rank: 3,
                displayName: 'Third Learner With Long Alias',
              ),
            ],
            selectedStage: 0,
            onStageChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    FlutterError.onError = previousOnError;

    final overflowErrors = flutterErrors.where((error) {
      return error.exceptionAsString().contains('RenderFlex overflowed');
    });
    final unexpectedErrors = flutterErrors.where((error) {
      return !error.exceptionAsString().contains('RenderFlex overflowed');
    });

    expect(unexpectedErrors, isEmpty);
    expect(overflowErrors, isEmpty);
  });
}

LeaderboardEntry _entry({
  required int rank,
  required String displayName,
}) {
  return LeaderboardEntry(
    childId: 'child-$rank',
    parentId: 'parent',
    displayName: displayName,
    ageStage: 3,
    totalScore: 100 - rank,
    completedLevels: 12 - rank,
    totalStars: 40 - rank,
    rewardCount: 3,
    updatedAt: DateTime.utc(2026),
  );
}
