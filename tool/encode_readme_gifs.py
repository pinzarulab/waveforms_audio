"""Encode Flutter-rendered README frames. Requires Python 3 and Pillow.

Run from any directory after `flutter test tool/render_readme_gifs.dart`.
Outputs tracked GIF assets under docs/images/styles; raw frames stay in build/.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
STYLES = (
    "orb", "liquidOrb", "wave", "ribbon", "bars", "upwardBars", "voiceBars",
    "mirrorSpectrum", "halo", "voiceBloom", "pulseRings", "dotSpectrum",
    "capsuleBars", "minimalLine",
)


def main():
    output = ROOT / "docs/images/styles"
    output.mkdir(parents=True, exist_ok=True)
    for style in STYLES:
        paths = sorted((ROOT / "build/readme-frames" / style).glob("*.png"))
        if len(paths) != 50:
            raise RuntimeError(f"{style}: expected 50 frames; run the Flutter exporter first")
        frames = []
        for path in paths:
            with Image.open(path) as image:
                frames.append(image.convert("RGB"))
        # One palette per animation avoids flickering quantization between frames.
        sheet = Image.new("RGB", (320 * 10, 200 * 5))
        for index, frame in enumerate(frames):
            sheet.paste(frame, (index % 10 * 320, index // 10 * 200))
        palette = sheet.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
        indexed = [frame.quantize(palette=palette, dither=Image.Dither.FLOYDSTEINBERG)
                   for frame in frames]
        target = output / f"{style}.gif"
        indexed[0].save(target, save_all=True, append_images=indexed[1:],
                        duration=80, loop=0, optimize=True, disposal=1)
        with Image.open(target) as result:
            assert result.size == (320, 200)
            # GIF encoding may merge identical adjacent frames.
            assert 1 < result.n_frames <= 50, (style, result.n_frames)
            assert result.info["loop"] == 0
            duration = 0
            for index in range(result.n_frames):
                result.seek(index)
                duration += result.info["duration"]
            assert duration == 4000, (style, duration)
        print(f"{style}: {target.stat().st_size / 1024:.0f} KiB")


if __name__ == "__main__":
    main()
