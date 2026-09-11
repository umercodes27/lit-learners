import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/activity_data.dart';
import 'package:little_learners/services/content/activity_pack_loader.dart';
import 'package:little_learners/widgets/activities/activity_audio.dart';
import 'package:little_learners/widgets/activities/activity_stage.dart';
import 'package:little_learners/widgets/activities/story_interactive_widget.dart';

/// A story's narration has to last as long as the story it narrates.
///
/// The bug this pins: age 3's "My Day" shipped a 1.1-second clip — the title
/// read aloud, not the story — under the right filename. The screen ends a
/// story when its narration ends, so the child saw the first picture, heard
/// "My Day", and the level was over. The other four pictures were never
/// reached and there was nothing to say the story had been cut short.
///
/// A narration that is merely *missing* is handled: the widget falls back to a
/// timer and at least shows every picture. A narration that is present but too
/// short is worse than none, and nothing caught it, because a truncated file is
/// a perfectly valid file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final packs = <int, String>{
    2: ActivityPackLoader.age2Path,
    3: ActivityPackLoader.age3Path,
    4: ActivityPackLoader.age4Path,
  };

  for (final entry in packs.entries) {
    test('age ${entry.key}: every story is narrated to its last picture',
        () async {
      final pack = (await ActivityPackLoader().load(path: entry.value)).pack!;
      final complaints = <String>[];

      for (final module in pack.modules) {
        for (final level in module.levels) {
          final data = level.data;
          if (data is! StoryInteractiveData) continue;

          final narration = data.audioNarration;
          if (narration == null || data.illustrations.isEmpty) continue;

          final Duration spoken;
          try {
            spoken = _mp3Duration(await rootBundle.load(narration));
          } on Object catch (e) {
            complaints.add('${level.key}: could not read $narration ($e)');
            continue;
          }

          // The last picture is only ever shown if the voice is still going
          // when its turn comes.
          final lastPicture = data.illustrations.last.startMs;
          if (spoken.inMilliseconds < lastPicture) {
            complaints.add(
              '${level.key} ("${data.title}"): narration is '
              '${(spoken.inMilliseconds / 1000).toStringAsFixed(1)}s but the '
              'last of ${data.illustrations.length} pictures is not due until '
              '${(lastPicture / 1000).toStringAsFixed(1)}s — the story is cut '
              'off before the child sees it',
            );
          }
        }
      }

      expect(complaints, isEmpty,
          reason: 'age ${entry.key} has a story that stops early:\n'
              '${complaints.join('\n')}');
    });
  }

  // The other half: however long the voice lasts, the pictures get shown.
  // "My Day" is the longest picture sequence in the app — five, timed out to
  // twenty seconds — and the timeline used to stop at twenty flat, so the last
  // picture appeared for no time at all.
  testWidgets('a five-picture story reaches its fifth picture', (tester) async {
    final pack =
        (await ActivityPackLoader().load(path: ActivityPackLoader.age3Path))
            .pack!;
    final data = pack
        .levelByKey('storytelling', 'daily_routine_stories')!
        .data as StoryInteractiveData;

    expect(data.illustrations, hasLength(5));

    await tester.pumpWidget(MaterialApp(
      home: StoryInteractiveWidget(data: data, audio: _SilentAudio()),
    ));
    await tester.pump();

    // The timeline is a periodic timer, so it has to be stepped rather than
    // jumped: one long pump fires it once.
    var reached = 0;
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      final stage = tester.any(find.byType(ActivityStage))
          ? tester.widget<ActivityStage>(find.byType(ActivityStage))
          : null;
      final index = stage?.roundIndex;
      if (index != null && index > reached) reached = index;
    }

    expect(reached, 4,
        reason: 'the story stopped on picture ${reached + 1} of 5');
  });
}

/// Audio that answers instantly.
///
/// The real [ActivityAudio] talks to audioplayers, which has no platform side
/// under `flutter test`: its futures never complete, so a screen that awaits
/// one stalls forever.
class _SilentAudio extends ActivityAudio {
  @override
  Future<void> playPrompt(String? assetPath) async {}

  @override
  Future<void> playCorrect() async {}

  @override
  Future<void> playWrong() async {}

  @override
  Future<void> stopPrompt() async {}

  @override
  Future<void> dispose() async {}
}

/// How long a constant-bitrate MP3 runs, from its own header.
///
/// The story narrations are all CBR, so the length is just the audio bytes
/// over the byte rate — no decoding and no plugin, which matters because
/// audioplayers has no platform side under `flutter test`.
Duration _mp3Duration(ByteData data) {
  final bytes = data.buffer.asUint8List();

  // Skip the ID3v2 tag if there is one. Its size is four seven-bit bytes.
  var offset = 0;
  if (bytes.length > 10 &&
      bytes[0] == 0x49 &&
      bytes[1] == 0x44 &&
      bytes[2] == 0x33) {
    offset = 10 +
        ((bytes[6] << 21) | (bytes[7] << 14) | (bytes[8] << 7) | bytes[9]);
  }

  if (offset + 4 > bytes.length) {
    throw const FormatException('no audio after the tag');
  }
  // Frame sync: eleven set bits.
  if (bytes[offset] != 0xFF || (bytes[offset + 1] & 0xE0) != 0xE0) {
    throw const FormatException('not an MPEG frame');
  }

  const bitrates = [
    0, 32, 40, 48, 56, 64, 80, 96, //
    112, 128, 160, 192, 224, 256, 320, 0,
  ];
  final kbps = bitrates[(bytes[offset + 2] >> 4) & 0xF];
  if (kbps == 0) throw const FormatException('unusable bitrate');

  final seconds = (bytes.length - offset) / (kbps * 1000 / 8);
  return Duration(milliseconds: (seconds * 1000).round());
}
