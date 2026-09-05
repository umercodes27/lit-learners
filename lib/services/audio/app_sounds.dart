/// Every sound the app can make, and where it lives.
///
/// One place, so a screen never spells out an asset path. Paths are relative
/// to `assets/`, which is what `audioplayers` expects from an `AssetSource`.
///
/// The files are cut by `tool/prepare_audio.py` from the masters in
/// `assets/audio/_masters/`. Effects are mono 22.05kHz WAV — short sounds do
/// not need stereo at 44.1kHz, and WAV skips the decode step that would delay
/// a tap. Music stays MP3, where the file size matters and 40ms of latency
/// does not.
library;

/// A short one-shot. These overlap: two stars landing make two sounds.
enum Sfx {
  /// Every tappable in the app. Fired from `Squishy`, which is the one place
  /// every button, card and tile already passes through.
  tap('audio/sfx/tap.wav'),

  quizCorrect('audio/sfx/quiz-correct.wav'),

  /// Deliberately gentle. At one to four years old a wrong answer is not a
  /// failure, and a buzzer teaches a child to stop trying.
  quizWrong('audio/sfx/quiz-wrong.mp3'),

  starPop('audio/sfx/star-pop.wav'),

  /// Tapping something that is not open yet.
  locked('audio/sfx/locked.wav'),

  /// The next stop on the map opens up.
  levelUnlocked('audio/sfx/level-unlocked.mp3'),

  /// The trophy at the end of a subject's map.
  moduleComplete('audio/sfx/module-complete.wav');

  const Sfx(this.asset);

  final String asset;
}

/// A looping bed. Only ever one plays at a time.
enum MusicTrack {
  /// Everywhere a child is choosing what to do: the learner picker, the
  /// module grid, the level maps.
  home('audio/music/home.mp3'),

  /// The celebration screen, and only that.
  celebration('audio/music/celebration.mp3');

  const MusicTrack(this.asset);

  final String asset;
}
