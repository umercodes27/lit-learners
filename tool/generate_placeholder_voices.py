"""Fills in the age-4 voice clips the pack names but never shipped.

Run from the repo root:  python3 tool/generate_placeholder_voices.py

PLACEHOLDERS. These are synthesised, not recorded, and they are not cleared
for release. They come from the undocumented endpoint Google Translate's own
page calls, which is fine for hearing the app work end to end and is not a
licence to ship. Before release either replace them with real recordings — six
short phrases and fifteen numbers is one short session with a phone — or
regenerate them through a licensed service (Google Cloud TTS, Azure Speech)
with an account key.

What was missing, and why it mattered:

* The two "find and tap" levels name six recordings — three English sentences
  and three Urdu words — that are not in the repo. A named-but-absent clip
  plays as silence, and these levels ask their whole question in audio.
* "Counting 1 to 20" asks for fifteen stars and twenty apples, and the pack
  ships number clips 1 to 5. Every tap from the sixth on was silent.

The code now falls back to the device voice in both cases, so this script is
about consistency rather than rescue: a clip sounds the same on every platform,
where the device voice is good on a phone, absent in some browsers, and a
different voice from the recordings around it.

Pure standard library on purpose, matching tool/prepare_audio.py: there is no
pip on the build machine.
"""

import os
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AGE3 = os.path.join(ROOT, 'assets', 'age3', 'audio')
AGE4 = os.path.join(ROOT, 'assets', 'age4', 'audio')

ENDPOINT = 'https://translate.google.com/translate_tts'
# Without a browser agent the endpoint returns 403.
AGENT = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko)'

# Exactly the paths assets/age4/little-learners-age4-data.json asks for.
SENTENCES = {
    'en/sentence_dog_runs.mp3': ('The Dog runs', 'en'),
    'en/sentence_cat_sits.mp3': ('The Cat sits', 'en'),
    'en/sentence_duck_swims.mp3': ('The Duck swims', 'en'),
    'ur/word_seb.mp3': ('سیب', 'ur'),
    'ur/word_kela.mp3': ('کیلا', 'ur'),
    'ur/word_billi.mp3': ('بلی', 'ur'),
}

# 1-5 were already recorded; the level counts to 20.
NUMBERS = {f'num/{n}.mp3': (str(n), 'en') for n in range(6, 21)}

# The age-3 alphabet tracing names a clip per letter and only five were cut, so
# twenty-one of the twenty-six letters were traced in silence — on levels where
# hearing the letter is the lesson.
AGE3_LETTERS = {
    f'en/letter_{c}.mp3': (c, 'en')
    for c in 'BDFGHIJKLNOPQRTUVWXYZ'
}


def fetch(text, language):
    query = urllib.parse.urlencode({
        'ie': 'UTF-8',
        'q': text,
        'tl': language,
        'client': 'tw-ob',
    })
    request = urllib.request.Request(
        f'{ENDPOINT}?{query}',
        headers={'User-Agent': AGENT},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read()


def is_mp3(data):
    if data[:3] == b'ID3':
        return True
    return len(data) > 2 and data[0] == 0xFF and (data[1] & 0xE0) == 0xE0


def main():
    jobs = {
        **{path: (text, lang, AGE4) for path, (text, lang) in SENTENCES.items()},
        **{path: (text, lang, AGE4) for path, (text, lang) in NUMBERS.items()},
        **{
            path: (text, lang, AGE3)
            for path, (text, lang) in AGE3_LETTERS.items()
        },
    }
    written = 0

    for relative, (text, language, pack) in jobs.items():
        destination = os.path.join(pack, relative)
        os.makedirs(os.path.dirname(destination), exist_ok=True)

        try:
            audio = fetch(text, language)
        except Exception as error:  # noqa: BLE001 - report and carry on
            print(f'{relative:32s} FAILED ({error})')
            continue

        # A blocked request comes back as an HTML error page with a 200, which
        # would otherwise be written out as a silent "clip".
        if not is_mp3(audio):
            print(f'{relative:32s} FAILED (not audio, {len(audio)} bytes)')
            continue

        with open(destination, 'wb') as out:
            out.write(audio)
        written += 1
        print(f'{relative:32s} {text[:22]:24s} {len(audio) // 1024:>3}KB')

        # The endpoint is somebody else's, so ask gently.
        time.sleep(0.4)

    print(f'\n{written}/{len(jobs)} written')
    if written != len(jobs):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
