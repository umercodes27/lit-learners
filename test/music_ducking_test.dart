import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/services/audio/audioplayers_sound_controller.dart';
import 'package:little_learners/services/audio/sound_settings_store.dart';

/// The bed only has to get out of the way of a voice, but it has to do it for
/// as long as *any* voice is talking. Several things speak on one screen — the
/// koala explains it, the activity reads the prompt, a letter is spoken aloud
/// — and they overlap freely.
AudioplayersSoundController controller() => AudioplayersSoundController(
      store: InMemorySoundSettingsStore(
        const SoundSettings(muted: false, musicVolume: 0.28, sfxVolume: 0.75),
      ),
      requiresUserGesture: false,
    );

void main() {
  test('a voice brings the music down and hands it back', () async {
    final sound = controller();
    final full = sound.effectiveMusicVolume;

    await sound.duck();
    expect(sound.effectiveMusicVolume, lessThan(full));

    await sound.unduck();
    expect(sound.effectiveMusicVolume, full);
  });

  test('the second voice to finish is the one that restores the music',
      () async {
    final sound = controller();
    final full = sound.effectiveMusicVolume;

    // A spoken prompt running into a reward cue.
    await sound.duck();
    await sound.duck();

    await sound.unduck();
    expect(sound.effectiveMusicVolume, lessThan(full),
        reason: 'someone is still talking');

    await sound.unduck();
    expect(sound.effectiveMusicVolume, full);
  });

  test('an unmatched unduck cannot leave the music owing a duck', () async {
    final sound = controller();
    final full = sound.effectiveMusicVolume;

    // A screen disposing after its sound had already finished.
    await sound.unduck();
    expect(sound.effectiveMusicVolume, full);

    await sound.duck();
    expect(sound.effectiveMusicVolume, lessThan(full),
        reason: 'the stray unduck must not have been banked against this');
  });

  test('a voice over silence stays silent', () async {
    final sound = controller();
    await sound.setMuted(true);

    await sound.duck();
    expect(sound.effectiveMusicVolume, 0);
    await sound.unduck();
    expect(sound.effectiveMusicVolume, 0);
  });
}
