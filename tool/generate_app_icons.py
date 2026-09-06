"""Cuts the launcher icons for every platform from the koala portrait.

Run from the repo root:  python tool/generate_app_icons.py

The source is assets/images/koala/koala_guide_portrait.png, the same koala the
guide widget shows, so the icon on the home screen is the character the child
meets inside the app. It is a 1254x1254 yellow disc on a cream ground, which
decides how each platform is fed:

* iOS and the legacy Android mipmaps get the full square. iOS masks it to a
  squircle itself, and the only thing that mask trims is the cream in the
  corners.
* Android adaptive icons need a 108dp canvas whose outer 18dp on each side the
  launcher may crop. So the disc is cut out and drawn at 72dp, leaving cream as
  the background layer: a circle-masked launcher lands exactly on the disc, and
  a rounded-square one shows it as a sticker on cream.
* Web maskable icons reserve the outer 10%, so the disc is drawn at 80%.

Re-run after replacing the source portrait; nothing here is hand-edited.
"""

import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "assets", "images", "koala", "koala_guide_portrait.png")

# Sampled from the source: the ground the disc sits on. Also the Android
# adaptive background layer, so the two agree wherever a launcher shows both.
CREAM = (254, 253, 244)

IOS_DIR = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
IOS_ICONS = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

ANDROID_RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
# Density bucket -> px per 48dp launcher icon. The adaptive foreground is the
# same bucket at 108dp, i.e. 2.25x these.
ANDROID_DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}

WEB_DIR = os.path.join(ROOT, "web")


def load_source():
    image = Image.open(SOURCE).convert("RGB")
    if image.width != image.height:
        raise SystemExit(f"source must be square, got {image.size}")
    return image


def flattened(image, size):
    """The whole square, downscaled, opaque. iOS rejects an alpha channel."""
    return image.resize((size, size), Image.LANCZOS)


def disc(image, size):
    """Just the yellow disc, circle-masked, transparent outside."""
    cut = image.resize((size, size), Image.LANCZOS).convert("RGBA")
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size * 4 - 1, size * 4 - 1), fill=255)
    cut.putalpha(mask.resize((size, size), Image.LANCZOS))
    return cut


def disc_on_cream(image, size, fraction):
    """The disc centred at `fraction` of the canvas, the rest cream."""
    canvas = Image.new("RGB", (size, size), CREAM)
    inner = max(1, round(size * fraction))
    offset = (size - inner) // 2
    cut = disc(image, inner)
    canvas.paste(cut, (offset, offset), cut)
    return canvas


def disc_on_transparent(image, size, fraction):
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = max(1, round(size * fraction))
    offset = (size - inner) // 2
    cut = disc(image, inner)
    canvas.paste(cut, (offset, offset), cut)
    return canvas


def write(image, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, "PNG")
    print("wrote", os.path.relpath(path, ROOT))


def main():
    source = load_source()

    for name, size in IOS_ICONS.items():
        write(flattened(source, size), os.path.join(IOS_DIR, name))

    for bucket, size in ANDROID_DENSITIES.items():
        write(
            flattened(source, size),
            os.path.join(ANDROID_RES, f"mipmap-{bucket}", "ic_launcher.png"),
        )
        # 108dp foreground, disc drawn at the 72dp the launcher must keep.
        canvas = round(size * 108 / 48)
        write(
            disc_on_transparent(source, canvas, 72 / 108),
            os.path.join(ANDROID_RES, f"mipmap-{bucket}", "ic_launcher_foreground.png"),
        )

    write(flattened(source, 16), os.path.join(WEB_DIR, "favicon.png"))
    for size in (192, 512):
        write(flattened(source, size), os.path.join(WEB_DIR, "icons", f"Icon-{size}.png"))
        write(
            disc_on_cream(source, size, 0.8),
            os.path.join(WEB_DIR, "icons", f"Icon-maskable-{size}.png"),
        )


if __name__ == "__main__":
    main()
