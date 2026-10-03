"""Portable asset regressions; all files are synthetic and temporary."""
import contextlib
import io
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from PIL import Image
import shrink_sayings as pack


class ImagePackagingTests(unittest.TestCase):
    def test_all_exif_orientations(self):
        # Independent expected corner positions: TL, TR, BL, BR.
        expected = {
            1: (0, 1, 2, 3), 2: (1, 0, 3, 2), 3: (3, 2, 1, 0),
            4: (2, 3, 0, 1), 5: (0, 2, 1, 3), 6: (2, 0, 3, 1),
            7: (3, 1, 2, 0), 8: (1, 3, 0, 2),
        }
        colors = [(255, 0, 0), (0, 255, 0), (0, 0, 255), (255, 255, 0)]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for orientation, corners in expected.items():
                with self.subTest(orientation=orientation):
                    image = Image.new('RGB', (160, 100))
                    for box, color in zip([(0, 0, 80, 50), (80, 0, 160, 50),
                                           (0, 50, 80, 100), (80, 50, 160, 100)], colors):
                        image.paste(color, box)
                    exif = Image.Exif(); exif[274] = orientation
                    source, dest = root / 'source.jpg', root / 'output.webp'
                    image.save(source, quality=100, subsampling=0, exif=exif)
                    pack.convert(source, dest)
                    with Image.open(dest) as result:
                        self.assertEqual(result.size, (100, 160) if orientation >= 5 else (160, 100))
                        self.assertNotIn(274, result.getexif())
                        w, h = result.size
                        samples = [(w // 4, h // 4), (3*w // 4, h // 4),
                                   (w // 4, 3*h // 4), (3*w // 4, 3*h // 4)]
                        for point, index in zip(samples, corners):
                            actual = result.getpixel(point)
                            self.assertLess(sum(abs(a-b) for a, b in zip(actual, colors[index])), 40)

    def test_bounds_no_upscale_and_alpha(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for size, expected in [((3000, 1000), (1280, 427)), ((1000, 3000), (640, 1920)),
                                   ((90, 60), (90, 60))]:
                image = Image.new('RGBA', size, (255, 0, 0, 128))
                image.save(root / 'source.png')
                pack.convert(root / 'source.png', root / 'output.webp')
                with Image.open(root / 'output.webp') as result:
                    self.assertEqual(result.size, expected)
                    self.assertEqual(result.getpixel((0, 0))[3], 128)
            # Palette PNGs store transparency in metadata, not an alpha band.
            indexed = Image.new('P', (20, 20), 0)
            indexed.putpalette([255, 0, 0] + [0, 0, 0] * 255)
            indexed.save(root / 'indexed.png', transparency=0)
            pack.convert(root / 'indexed.png', root / 'indexed.webp')
            with Image.open(root / 'indexed.webp') as result:
                self.assertEqual(result.getpixel((0, 0))[3], 0)

    def test_order_metadata_cache_and_stale_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); source = root / 'source'; source.mkdir()
            assets = root / 'assets'; output = assets / 'sayings'
            (source / 'order.txt').write_text('sayings/02.png\nsayings/01.jpg\n')
            metadata = b'[{"number":2,"focusX":0.25,"focusY":0.4}]\n'
            (source / 'approved-sources.json').write_bytes(metadata)
            for name in ['02.png', '01.jpg']:
                Image.new('RGB', (80, 60), 'red').save(source / name)
            hashes = {p.name: pack.digest(p) for p in source.iterdir()}
            with contextlib.redirect_stdout(io.StringIO()):
                pack.generate(source, assets)
                self.assertEqual((output / 'order.txt').read_text(), 'sayings/02.webp\nsayings/01.webp\n')
                self.assertEqual((output / 'approved-sources.json').read_bytes(), metadata)
                times = {p.name: p.stat().st_mtime_ns for p in output.glob('*.webp')}
                (output / 'obsolete.jpg').write_bytes(b'stale')
                pack.generate(source, assets)
                self.assertFalse((output / 'obsolete.jpg').exists())
                self.assertEqual(times, {p.name: p.stat().st_mtime_ns for p in output.glob('*.webp')})
                # Content changes must regenerate even when timestamps go backwards.
                Image.new('RGB', (80, 60), 'blue').save(source / '01.jpg')
                os.utime(source / '01.jpg', (1, 1))
                pack.generate(source, assets)
                with Image.open(output / '01.webp') as result:
                    self.assertGreater(result.getpixel((40, 30))[2], 200)
                self.assertEqual(times['02.webp'], (output / '02.webp').stat().st_mtime_ns)
                # Corrupted output and a changed encoder both invalidate the cache.
                (output / '02.webp').write_bytes(b'broken')
                pack.generate(source, assets)
                with Image.open(output / '02.webp') as result:
                    result.load()
                with patch.object(pack, 'encoder_identity', return_value='new-encoder'), \
                     patch.object(pack, 'convert', wraps=pack.convert) as convert:
                    pack.generate(source, assets)
                    self.assertEqual(convert.call_count, 2)
            for name in ['order.txt', 'approved-sources.json', '02.png']:
                self.assertEqual(hashes[name], pack.digest(source / name))

    def test_missing_webp_fails_before_output(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(pack.features, 'check', return_value=False):
            root = Path(directory)
            with self.assertRaisesRegex(RuntimeError, 'no WebP support'):
                pack.generate(root / 'source', root / 'assets')
            self.assertFalse((root / 'assets').exists())


if __name__ == '__main__':
    unittest.main()
