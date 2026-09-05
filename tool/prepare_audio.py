"""Turns the delivered audio masters into the files the app ships.

Run from the repo root:  python tool/prepare_audio.py

The masters land in assets/audio/_masters/ as they were delivered. They are
deliberately *not* declared in pubspec.yaml, so they stay in the repo for
re-cutting later without adding a byte to the APK.

Three things this does, and why:

* Trims. The delivered tap is 1.17s long, of which 1.07s is silence, and the
  correct-answer chime is 5.15s while the quiz auto-advances after 1.15s. Left
  alone, fast tapping turns to mush and the chime is cut off every time.
* Strips leading silence. The star pop had 100ms of it, which would land the
  sound after the star it belongs to.
* Downmixes to mono at 22.05kHz. Short effects do not need stereo at 44.1kHz,
  and this is a quarter of the bytes.

Every cut gets a short fade so it ends on silence rather than on a click.

Pure standard library on purpose: there is no ffmpeg on the build machine.
MP3s are cut on frame boundaries, so nothing is re-encoded.
"""

import os
import wave
import audioop
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MASTERS = os.path.join(ROOT, 'assets', 'audio', '_masters')
SFX = os.path.join(ROOT, 'assets', 'audio', 'sfx')
MUSIC = os.path.join(ROOT, 'assets', 'audio', 'music')

TARGET_RATE = 22050
FADE_MS = 120

# master -> (output name, start seconds, end seconds)
WAV_JOBS = {
    'squishy tap.wav': ('tap.wav', 0.0, 0.16),
    'Locked-Item.wav': ('locked.wav', 0.0, 0.72),
    'quiz-correct.wav': ('quiz-correct.wav', 0.0, 1.60),
    'star-popping.wav': ('star-pop.wav', 0.08, 1.20),
    'Module Complete.wav': ('module-complete.wav', 0.0, 2.55),
}

# master -> (output name, seconds to keep; None keeps all)
MP3_JOBS = {
    'quiz-wrong.mp3': ('quiz-wrong.mp3', None),
    'lvl-unlocked.mp3': ('level-unlocked.mp3', None),
    'Home-Subject-Loops.mp3': ('home.mp3', None),
    # 158s at 256kbps is 4.9MB for one screen. Forty seconds loops fine.
    'victory.mp3': ('celebration.mp3', 40.0),
}

BITRATES = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128,
            160, 192, 224, 256, 320, 0]
RATES = {0: 44100, 1: 48000, 2: 32000, 3: 0}


def cut_wav(src, dst, start, end):
    with wave.open(src, 'rb') as w:
        channels, width, rate = w.getnchannels(), w.getsampwidth(), \
            w.getframerate()
        raw = w.readframes(w.getnframes())

    frame = width * channels
    raw = raw[int(start * rate) * frame:int(end * rate) * frame]

    if channels == 2:
        raw = audioop.tomono(raw, width, 0.5, 0.5)
    if rate != TARGET_RATE:
        raw, _ = audioop.ratecv(raw, width, 1, rate, TARGET_RATE, None)

    # Fade the tail so a cut lands on silence instead of a click.
    fade = min(int(TARGET_RATE * FADE_MS / 1000), len(raw) // width)
    if fade > 0:
        head = raw[:-fade * width]
        tail = bytearray()
        for i in range(fade):
            chunk = raw[len(head) + i * width:len(head) + (i + 1) * width]
            gain = 1.0 - (i / fade)
            tail += audioop.mul(chunk, width, gain)
        raw = head + bytes(tail)

    with wave.open(dst, 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(width)
        out.setframerate(TARGET_RATE)
        out.writeframes(raw)


def cut_mp3(src, dst, seconds):
    data = open(src, 'rb').read()
    start = 0
    if data[:3] == b'ID3' and len(data) > 10:
        b = data[6:10]
        size = ((b[0] & 0x7f) << 21 | (b[1] & 0x7f) << 14
                | (b[2] & 0x7f) << 7 | (b[3] & 0x7f))
        start = 10 + size

    if seconds is None:
        shutil.copyfile(src, dst)
        return

    i, kept = start, 0.0
    while i < len(data) - 4 and kept < seconds:
        if data[i] == 0xFF and (data[i + 1] & 0xE0) == 0xE0:
            version = (data[i + 1] >> 3) & 3
            layer = (data[i + 1] >> 1) & 3
            bitrate_index = (data[i + 2] >> 4) & 0xF
            rate_index = (data[i + 2] >> 2) & 3
            padding = (data[i + 2] >> 1) & 1
            if (version == 3 and layer == 1
                    and bitrate_index not in (0, 15) and rate_index != 3):
                bitrate = BITRATES[bitrate_index] * 1000
                rate = RATES[rate_index]
                length = int(144 * bitrate / rate) + padding
                if length > 4:
                    kept += 1152 / rate
                    i += length
                    continue
        i += 1

    with open(dst, 'wb') as out:
        out.write(data[start:i])


def main():
    os.makedirs(SFX, exist_ok=True)
    os.makedirs(MUSIC, exist_ok=True)

    for name, (out_name, start, end) in WAV_JOBS.items():
        src = os.path.join(MASTERS, name)
        dst = os.path.join(SFX, out_name)
        cut_wav(src, dst, start, end)
        print(f'{name:24s} -> sfx/{out_name:22s} '
              f'{os.path.getsize(src) // 1024:>5}KB -> '
              f'{os.path.getsize(dst) // 1024:>5}KB')

    for name, (out_name, seconds) in MP3_JOBS.items():
        src = os.path.join(MASTERS, name)
        folder = MUSIC if out_name in ('home.mp3', 'celebration.mp3') else SFX
        dst = os.path.join(folder, out_name)
        cut_mp3(src, dst, seconds)
        where = 'music' if folder == MUSIC else 'sfx'
        print(f'{name:24s} -> {where}/{out_name:22s} '
              f'{os.path.getsize(src) // 1024:>5}KB -> '
              f'{os.path.getsize(dst) // 1024:>5}KB')


if __name__ == '__main__':
    main()
