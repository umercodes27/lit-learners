"""Extract every audio cue key in the app with the line that should be spoken.

Output is tool/cues.json, the input a text-to-speech batch needs:

    [{"key": "koala_quiz_start", "text": "...", "bucket": "koala",
      "lang": "en-US", "asset": "assets/audio/koala/koala_quiz_start.mp3"}]

Language is detected from the script the text is written in, not assumed:
the Urdu module's content is already authored in Urdu, so a cue carries one
line in one language rather than an English line needing translation.
"""

import collections
import io
import json
import pathlib
import re

REPO = pathlib.Path(__file__).resolve().parent.parent

# Where the resolver looks. Koala guide cues default to audio/koala;
# learning-card cues are played with assetBasePath audio/learning
# (ContentAudioButton.learningAssetBasePath).
BUCKET_DIR = {
    "koala": "assets/audio/koala",
    "learning": "assets/audio/learning",
}

# Arabic script block - Urdu is written in it, English is not.
URDU = re.compile(r"[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]")


def constructor_bodies(source, name):
    """Yield the argument text of each `name( ... )` call, paren-balanced."""
    for match in re.finditer(re.escape(name) + r"\(", source):
        i = match.end()
        start = i
        depth = 1
        while i < len(source) and depth:
            char = source[i]
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
            i += 1
        yield source[start:i - 1]


def field(body, name):
    """Read a single-quoted Dart string field out of a constructor body."""
    match = re.search(name + r":\s*'([^']*)'", body)
    return match.group(1) if match else None


def collect():
    cues = {}

    sources = [
        # (file, constructor, field holding the spoken line, bucket)
        ("lib/data/koala_guide_content.dart", "KoalaGuideMessage", "message", "koala"),
        ("lib/data/seed_content.dart", "ContentItem", "prompt", "learning"),
    ]

    for rel, ctor, text_field, bucket in sources:
        source = (REPO / rel).read_text(encoding="utf-8")
        for body in constructor_bodies(source, ctor):
            key = field(body, "audioCueKey")
            text = field(body, text_field)
            if not key or not text:
                continue
            # First writer wins: a cue key reused across levels is one file.
            if key in cues:
                continue
            lang = "ur-PK" if URDU.search(text) else "en-US"
            cues[key] = {
                "key": key,
                "text": text,
                "bucket": bucket,
                "lang": lang,
                "asset": "%s/%s.mp3" % (BUCKET_DIR[bucket], key),
            }

    return cues


def main():
    cues = collect()
    rows = sorted(cues.values(), key=lambda c: (c["bucket"], c["key"]))

    out = REPO / "tool" / "cues.json"
    with io.open(out, "w", encoding="utf-8") as handle:
        json.dump(rows, handle, ensure_ascii=False, indent=2)
        handle.write("\n")

    counts = collections.Counter((c["bucket"], c["lang"]) for c in rows)
    chars = collections.Counter()
    for cue in rows:
        chars[cue["lang"]] += len(cue["text"])

    print("cues with a speakable line: %d" % len(rows))
    print()
    for (bucket, lang), n in sorted(counts.items()):
        print("  %-9s %-6s %3d cues" % (bucket, lang, n))
    print()
    print("characters to synthesize")
    for lang, n in sorted(chars.items()):
        print("  %-6s %6d" % (lang, n))
    print("  %-6s %6d" % ("TOTAL", sum(chars.values())))
    print()
    print("wrote %s" % out.relative_to(REPO))


if __name__ == "__main__":
    main()
