"""Generate Android launcher icons from the supplied original TFL artwork.

Run from the repository root: python3 tooling/build_launcher_icons.py
Requires Pillow. The source image is kept unchanged in assets/branding.
"""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "branding" / "tfl_logo.png"
RES = ROOT / "android" / "app" / "src" / "main" / "res"
LEGACY_SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}


def centered_icon(source: Image.Image, size: int, fraction: float, background):
    canvas = Image.new("RGBA", (size, size), background)
    art_size = round(size * fraction)
    artwork = source.resize((art_size, art_size), Image.Resampling.LANCZOS)
    offset = (size - art_size) // 2
    canvas.alpha_composite(artwork, (offset, offset))
    return canvas


def main():
    with Image.open(SOURCE) as image:
        source = image.convert("RGBA")
        for density, size in LEGACY_SIZES.items():
            target = RES / f"mipmap-{density}" / "ic_launcher.png"
            centered_icon(source, size, 0.82, "black").convert("RGB").save(target)

        # The centered two-thirds of an adaptive icon remains visible under
        # Android's round and shaped launcher masks.
        foreground = RES / "drawable-nodpi" / "ic_launcher_foreground.png"
        centered_icon(source, 432, 2 / 3, (0, 0, 0, 0)).save(foreground)


if __name__ == "__main__":
    main()
