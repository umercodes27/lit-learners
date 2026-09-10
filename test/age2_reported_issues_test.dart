import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/localization/urdu_letters.dart';
import 'package:little_learners/models/activity_data.dart';
import 'package:little_learners/services/content/activity_pack_loader.dart';
import 'package:little_learners/services/content/asset_availability.dart';
import 'package:little_learners/services/content/module_quiz_builder.dart';
import 'package:little_learners/views/child_dashboard/widgets/activity_chrome.dart';

/// Faults reported from the age-2 pack, each pinned so it cannot come back.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<dynamic> loadAge2() async =>
      (await ActivityPackLoader().load(path: ActivityPackLoader.age2Path))
          .pack!;

  group('shapes are the shape they are called', () {
    // blue_square.png was a 295x142 rectangle taught as "square", in the
    // Shapes & Colors level and again in the quiz built from it.
    test('the square image is square', () async {
      for (final age in [2, 3, 4]) {
        final bytes = await rootBundle.load('assets/age$age/img/blue_square.png');
        final decoded = await decodeImageFromList(
          bytes.buffer.asUint8List(),
        );
        expect(decoded.width, decoded.height,
            reason: 'age $age blue_square.png is '
                '${decoded.width}x${decoded.height}, not a square');
      }
    });
  });

  test('the parrot is taught the letter its name starts with', () async {
    final pack = await loadAge2();
    final level = pack.levelByKey('urdu', 'level_3')!;
    final data = level.data as IdentifyAndTapData;

    final parrot = data.items.firstWhere(
      (item) => item.promptImage?.endsWith('parrot.png') ?? false,
    );
    final correct = parrot.options.firstWhere((option) => option.isCorrect);

    // طوطا begins with ط, not ت.
    expect(UrduLetters.glyphFor(correct.label ?? ''), 'ط',
        reason: 'the parrot round teaches '
            '"${correct.label}" (${UrduLetters.glyphFor(correct.label ?? '')})');
  });

  test('the Urdu quiz asks its questions in Urdu', () async {
    final pack = await loadAge2();
    final quiz = ModuleQuizBuilder.build(
      pack.modules.firstWhere((m) => m.key == 'urdu'),
    );

    expect(quiz.isEmpty, isFalse, reason: 'the Urdu module should have a quiz');

    final latin = RegExp(r'[A-Za-z]');
    for (final question in quiz.questions) {
      expect(latin.hasMatch(question.prompt), isFalse,
          reason: 'asked in English with Urdu answers: "${question.prompt}"');
    }
  });

  group('the speaker only appears when there is something to play', () {
    tearDown(AssetAvailability.instance.debugReset);

    // assets/audio/learning/ is empty, so every seeded cue — tracing, drawing
    // and logic — drew a speaker that did nothing when pressed.
    testWidgets('hidden when the cue has no recording', (tester) async {
      AssetAvailability.instance.debugSeed({'assets/audio/learning/other.mp3'});

      await tester.pumpWidget(const MaterialApp(
        home: ContentAudioButton(audioCueKey: 'trace_letter_a'),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_up), findsNothing);
    });

    testWidgets('hidden when the level names no cue at all', (tester) async {
      AssetAvailability.instance.debugSeed(const {});

      await tester.pumpWidget(const MaterialApp(
        home: ContentAudioButton(audioCueKey: null),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_up), findsNothing);
    });
  });
}
