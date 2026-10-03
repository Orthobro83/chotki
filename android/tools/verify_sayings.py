#!/usr/bin/env python3
"""Verify the generated library or both APKs without launching the app."""
import argparse
import io
import zipfile
from pathlib import Path

from PIL import Image


def verify(source, read):
    names = [line.strip() for line in (source / 'order.txt').read_text().splitlines() if line.strip()]
    expected = [f"sayings/{Path(name).with_suffix('.webp').name}" for name in names]
    assert len(expected) == 365, f'expected 365 images, got {len(expected)}'
    assert read('sayings/order.txt').decode().splitlines() == expected, 'rotation order changed'
    assert read('sayings/approved-sources.json') == (source / 'approved-sources.json').read_bytes(), 'focal metadata changed'
    total = 0
    for original, generated in zip(names, expected):
        data = read(generated); total += len(data)
        with Image.open(source / Path(original).name) as image:
            w, h = image.size
            if image.getexif().get(274, 1) in (5, 6, 7, 8):
                w, h = h, w
        with Image.open(io.BytesIO(data)) as result:
            result.load()
            assert result.format == 'WEBP', generated
            assert result.width <= 1280 and result.height <= 1920, generated
            assert result.width <= w and result.height <= h, f'upscaled {generated}'
            assert abs(result.width / result.height - w / h) <= 1 / result.height, f'aspect ratio {generated}'
            assert result.getexif().get(274, 1) == 1, f'orientation metadata {generated}'
            assert not any(key in result.info for key in ('exif', 'icc_profile', 'xmp')), generated
    print(f'verified {len(expected)} upright WebP images, order and focal metadata; {total/1_000_000:.1f} MB')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('artifacts', type=Path, nargs='+', help='generated asset root or APK')
    args = parser.parse_args()
    for artifact in args.artifacts:
        print(artifact)
        if artifact.suffix == '.apk':
            with zipfile.ZipFile(artifact) as apk:
                verify(args.source, lambda name: apk.read('assets/' + name))
        else:
            verify(args.source, lambda name: (artifact / name).read_bytes())


if __name__ == '__main__':
    main()
