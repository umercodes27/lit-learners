import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/services/audio/koala_audio_player.dart';

void main() {
  group('KoalaAudioCueSource', () {
    test('resolves cue keys to bundled koala audio assets', () {
      final source = KoalaAudioCueSource.resolve('koala_math_intro');

      expect(source?.source, KoalaAudioPlaybackSource.asset);
      expect(source?.path, 'audio/koala/koala_math_intro.mp3');
    });

    test('keeps explicit asset paths and extensions', () {
      final source = KoalaAudioCueSource.resolve(
        'assets/audio/koala/custom_cue.m4a',
      );

      expect(source?.source, KoalaAudioPlaybackSource.asset);
      expect(source?.path, 'audio/koala/custom_cue.m4a');
    });

    test('resolves remote urls for backend-hosted audio', () {
      final source = KoalaAudioCueSource.resolve(
        'https://cdn.example.com/audio/koala_math_intro.mp3',
      );

      expect(source?.source, KoalaAudioPlaybackSource.remoteUrl);
      expect(
        source?.path,
        'https://cdn.example.com/audio/koala_math_intro.mp3',
      );
    });
  });

  group('AudioplayersKoalaAudioPlayer', () {
    test('plays bundled asset cue paths', () async {
      final playedAssets = <String>[];
      final player = AudioplayersKoalaAudioPlayer(
        playAsset: (assetPath) async => playedAssets.add(assetPath),
      );

      final result = await player.playCue('koala_dashboard_stage1');

      expect(playedAssets, ['audio/koala/koala_dashboard_stage1.mp3']);
      expect(result.didPlay, isTrue);
      expect(result.source, KoalaAudioPlaybackSource.asset);
      expect(result.resolvedPath, 'audio/koala/koala_dashboard_stage1.mp3');
    });

    test('plays remote audio cue urls', () async {
      final playedUrls = <String>[];
      final player = AudioplayersKoalaAudioPlayer(
        playRemoteUrl: (url) async => playedUrls.add(url),
      );

      final result = await player.playCue(
        'https://cdn.example.com/audio/koala_dashboard_stage1.mp3',
      );

      expect(
        playedUrls,
        ['https://cdn.example.com/audio/koala_dashboard_stage1.mp3'],
      );
      expect(result.didPlay, isTrue);
      expect(result.source, KoalaAudioPlaybackSource.remoteUrl);
    });

    test('uses fallback cue if audio playback fails', () async {
      final fallback = _FakeFallbackKoalaAudioPlayer();
      final player = AudioplayersKoalaAudioPlayer(
        fallbackPlayer: fallback,
        playAsset: (_) async => throw StateError('missing file'),
      );

      final result = await player.playCue('koala_missing');

      expect(fallback.playedCueKeys, ['koala_missing']);
      expect(result.didPlay, isTrue);
      expect(result.source, KoalaAudioPlaybackSource.systemCue);
      expect(result.message, 'Audio file unavailable; played fallback cue.');
    });
  });
}

class _FakeFallbackKoalaAudioPlayer implements KoalaAudioPlayer {
  final playedCueKeys = <String?>[];

  @override
  Future<KoalaAudioPlaybackResult> playCue(String? cueKey) async {
    playedCueKeys.add(cueKey);
    return KoalaAudioPlaybackResult(
      cueKey: cueKey,
      didPlay: true,
      source: KoalaAudioPlaybackSource.systemCue,
    );
  }
}
