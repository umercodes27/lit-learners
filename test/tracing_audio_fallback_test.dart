import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/activity_data.dart';
import 'package:little_learners/services/audio/glyph_speech.dart';
import 'package:little_learners/services/content/activity_pack_loader.dart';
import 'package:little_learners/services/content/asset_availability.dart';
import 'package:little_learners/widgets/activities/activity_audio.dart';
import 'package:little_learners/widgets/activities/tracing_widget.dart';

/// What a tracing level says out loud.
///
/// The bug this pins: the age-3 pack names a recording for every glyph, but
/// only six were ever cut. Branching on "did the pack name a clip" instead of
/// "is the clip in the bundle" sent all thirty-one unrecorded glyphs down the
/// recorded path, where a missing file plays as silence — so a child got a
/// shape to trace and was never told what it was called.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpTracing(
    WidgetTester tester, {
    required TracingData data,
    required GlyphSpeech speech,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: TracingWidget(
        data: data,
        audio: ActivityAudio(),
        speech: speech,
      ),
    ));
    await tester.pump();
  }

  TracingData dataFor(String glyph, String? audio) => TracingData(
        title: 'Tracing',
        isRtl: false,
        items: [TracingItem(glyph: glyph, audio: audio)],
      );

  testWidgets('speaks a glyph whose named clip was never shipped',
      (tester) async {
    AssetAvailability.instance.debugSeed({'assets/age3/audio/en/letter_A.mp3'});
    final speech = _RecordingSpeech();

    await pumpTracing(
      tester,
      // Named, but not in the seeded bundle — the age-3 case.
      data: dataFor('B', 'assets/age3/audio/en/letter_B.mp3'),
      speech: speech,
    );

    expect(speech.spoken, ['B'],
        reason: 'an unshipped clip must fall through to the device voice');
  });

  testWidgets('stays quiet and plays the recording when one exists',
      (tester) async {
    AssetAvailability.instance.debugSeed({'assets/age3/audio/en/letter_A.mp3'});
    final speech = _RecordingSpeech();

    await pumpTracing(
      tester,
      data: dataFor('A', 'assets/age3/audio/en/letter_A.mp3'),
      speech: speech,
    );

    expect(speech.spoken, isEmpty,
        reason: 'a real recording still wins over the device voice');
  });

  testWidgets('still speaks a glyph that names no clip at all', (tester) async {
    AssetAvailability.instance.debugSeed(const {});
    final speech = _RecordingSpeech();

    await pumpTracing(tester, data: dataFor('7', null), speech: speech);

    expect(speech.spoken, ['7']);
  });

  // The count is the point: every one of these was silent before.
  test('the age-3 pack really does name clips it does not ship', () async {
    final result =
        await ActivityPackLoader().load(path: ActivityPackLoader.age3Path);

    final unshippedTracingClips = result.missingAssets
        .where((path) => path.contains('/letter_') || path.contains('/num/'))
        .length;

    expect(unshippedTracingClips, greaterThan(0),
        reason: 'if this reaches zero the clips were recorded — good news, '
            'but the fallback above is then untested by real content');
  });
}

/// A voice that records what it was asked to say instead of saying it.
class _RecordingSpeech extends GlyphSpeech {
  final List<String> spoken = <String>[];

  @override
  Future<void> speak(String text, {bool urdu = false}) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}
}
