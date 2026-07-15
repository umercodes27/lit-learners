import 'package:audioplayers/audioplayers.dart' as audio;
import 'package:flutter/services.dart';

enum KoalaAudioPlaybackSource {
  none,
  asset,
  remoteUrl,
  systemCue,
}

class KoalaAudioPlaybackResult {
  const KoalaAudioPlaybackResult({
    required this.cueKey,
    required this.didPlay,
    this.source = KoalaAudioPlaybackSource.none,
    this.resolvedPath,
    this.message,
  });

  final String? cueKey;
  final bool didPlay;
  final KoalaAudioPlaybackSource source;
  final String? resolvedPath;
  final String? message;
}

abstract class KoalaAudioPlayer {
  Future<KoalaAudioPlaybackResult> playCue(
    String? cueKey, {
    String? assetBasePath,
  });
}

class KoalaAudioCueSource {
  const KoalaAudioCueSource._({
    required this.source,
    required this.path,
  });

  factory KoalaAudioCueSource.asset(String path) {
    return KoalaAudioCueSource._(
      source: KoalaAudioPlaybackSource.asset,
      path: path,
    );
  }

  factory KoalaAudioCueSource.remoteUrl(String url) {
    return KoalaAudioCueSource._(
      source: KoalaAudioPlaybackSource.remoteUrl,
      path: url,
    );
  }

  final KoalaAudioPlaybackSource source;
  final String path;

  static KoalaAudioCueSource? resolve(
    String? cueKey, {
    String assetBasePath = 'audio/koala',
    String defaultExtension = '.mp3',
  }) {
    final trimmedCueKey = cueKey?.trim();
    if (trimmedCueKey == null || trimmedCueKey.isEmpty) return null;

    final uri = Uri.tryParse(trimmedCueKey);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.hasAuthority) {
      return KoalaAudioCueSource.remoteUrl(trimmedCueKey);
    }

    var assetPath = trimmedCueKey;
    if (assetPath.startsWith('assets/')) {
      assetPath = assetPath.substring('assets/'.length);
    }

    final hasFolder = assetPath.contains('/');
    final hasExtension = RegExp(r'\.[a-zA-Z0-9]+$').hasMatch(assetPath);

    if (!hasFolder) {
      assetPath = '$assetBasePath/$assetPath';
    }
    if (!hasExtension) {
      assetPath = '$assetPath$defaultExtension';
    }

    return KoalaAudioCueSource.asset(assetPath);
  }
}

class SystemKoalaAudioPlayer implements KoalaAudioPlayer {
  const SystemKoalaAudioPlayer();

  @override
  Future<KoalaAudioPlaybackResult> playCue(
    String? cueKey, {
    String? assetBasePath,
  }) async {
    final trimmedCueKey = cueKey?.trim();
    if (trimmedCueKey == null || trimmedCueKey.isEmpty) {
      return const KoalaAudioPlaybackResult(
        cueKey: null,
        didPlay: false,
        message: 'No audio cue is available.',
      );
    }

    await SystemSound.play(SystemSoundType.click);
    return KoalaAudioPlaybackResult(
      cueKey: trimmedCueKey,
      didPlay: true,
      source: KoalaAudioPlaybackSource.systemCue,
      message: 'Played guide cue.',
    );
  }
}

class AudioplayersKoalaAudioPlayer implements KoalaAudioPlayer {
  AudioplayersKoalaAudioPlayer({
    KoalaAudioPlayer fallbackPlayer = const SystemKoalaAudioPlayer(),
    String defaultAssetBasePath = 'audio/koala',
    Future<void> Function(String assetPath)? playAsset,
    Future<void> Function(String url)? playRemoteUrl,
  })  : _fallbackPlayer = fallbackPlayer,
        _defaultAssetBasePath = defaultAssetBasePath,
        _playAsset = playAsset,
        _playRemoteUrl = playRemoteUrl;

  final KoalaAudioPlayer _fallbackPlayer;
  final String _defaultAssetBasePath;
  final Future<void> Function(String assetPath)? _playAsset;
  final Future<void> Function(String url)? _playRemoteUrl;
  audio.AudioPlayer? _player;

  @override
  Future<KoalaAudioPlaybackResult> playCue(
    String? cueKey, {
    String? assetBasePath,
  }) async {
    final cueSource = KoalaAudioCueSource.resolve(
      cueKey,
      assetBasePath: assetBasePath ?? _defaultAssetBasePath,
    );
    if (cueSource == null) {
      return const KoalaAudioPlaybackResult(
        cueKey: null,
        didPlay: false,
        message: 'No audio cue is available.',
      );
    }

    try {
      switch (cueSource.source) {
        case KoalaAudioPlaybackSource.asset:
          await _playAssetSource(cueSource.path);
        case KoalaAudioPlaybackSource.remoteUrl:
          await _playRemoteUrlSource(cueSource.path);
        case KoalaAudioPlaybackSource.none:
        case KoalaAudioPlaybackSource.systemCue:
          return _fallbackPlayer.playCue(
            cueKey,
            assetBasePath: assetBasePath,
          );
      }

      return KoalaAudioPlaybackResult(
        cueKey: cueKey?.trim(),
        didPlay: true,
        source: cueSource.source,
        resolvedPath: cueSource.path,
        message: 'Played guide audio.',
      );
    } on Object {
      final fallbackResult = await _fallbackPlayer.playCue(
        cueKey,
        assetBasePath: assetBasePath,
      );
      return KoalaAudioPlaybackResult(
        cueKey: fallbackResult.cueKey,
        didPlay: fallbackResult.didPlay,
        source: fallbackResult.source,
        resolvedPath: fallbackResult.resolvedPath,
        message: fallbackResult.didPlay
            ? 'Audio file unavailable; played fallback cue.'
            : fallbackResult.message,
      );
    }
  }

  Future<void> _playAssetSource(String assetPath) async {
    final playAsset = _playAsset;
    if (playAsset != null) {
      await playAsset(assetPath);
      return;
    }

    await _audioPlayer.play(audio.AssetSource(assetPath));
  }

  Future<void> _playRemoteUrlSource(String url) async {
    final playRemoteUrl = _playRemoteUrl;
    if (playRemoteUrl != null) {
      await playRemoteUrl(url);
      return;
    }

    await _audioPlayer.play(audio.UrlSource(url));
  }

  audio.AudioPlayer get _audioPlayer {
    return _player ??= audio.AudioPlayer();
  }
}
