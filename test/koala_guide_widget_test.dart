import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/services/audio/koala_audio_player.dart';
import 'package:little_learners/widgets/koala_guide.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('KoalaGuide routes audio cue playback through provider',
      (tester) async {
    final player = _FakeKoalaAudioPlayer();

    await tester.pumpWidget(
      Provider<KoalaAudioPlayer>.value(
        value: player,
        child: const MaterialApp(
          home: Scaffold(
            body: KoalaGuide(
              message: 'Listen to Koala.',
              audioCueKey: 'koala_test_cue',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.volume_up));
    await tester.pump();

    expect(player.playedCueKeys, ['koala_test_cue']);
  });
}

class _FakeKoalaAudioPlayer implements KoalaAudioPlayer {
  final playedCueKeys = <String?>[];

  @override
  Future<KoalaAudioPlaybackResult> playCue(String? cueKey) async {
    playedCueKeys.add(cueKey);
    return KoalaAudioPlaybackResult(cueKey: cueKey, didPlay: true);
  }
}
