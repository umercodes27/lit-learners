import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/services/content/activity_pack_loader.dart';
import 'package:little_learners/widgets/activities/activity_audio.dart';
import 'package:little_learners/widgets/activities/activity_player.dart';

class _Silent extends ActivityAudio {
  @override
  Future<void> playPrompt(String? p) async {}
  @override
  Future<void> playCorrect() async {}
  @override
  Future<void> playWrong() async {}
  @override
  Future<void> stopPrompt() async {}
  @override
  Future<void> dispose() async {}
}

/// Every level of every pack is rendered on a phone-sized screen.
///
/// A pack is data, so a level can be broken by an edit to JSON that no
/// compiler will catch. This mounts each one through [ActivityPlayer] exactly
/// as the app does and fails on anything it throws.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final path in [
    ActivityPackLoader.age2Path,
    ActivityPackLoader.age3Path,
    ActivityPackLoader.age4Path,
  ]) {
    testWidgets('every level renders: $path', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final pack = (await ActivityPackLoader().load(path: path)).pack!;
      final failures = <String>[];

      for (final m in pack.modules) {
        for (final level in m.levels) {
          final where = 'age ${pack.age} ${m.key}/${level.key}';
          try {
            await tester.pumpWidget(MaterialApp(
              home: Scaffold(
                body: ActivityPlayer(data: level.data, audio: _Silent()),
              ),
            ));
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump(const Duration(milliseconds: 400));
            final e = tester.takeException();
            if (e != null) failures.add('$where: $e');
          } catch (e) {
            failures.add('$where THREW: $e');
          }
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  }
}
