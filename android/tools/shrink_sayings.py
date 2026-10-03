#!/usr/bin/env python3
"""Build upright WebP copies of the Mac library on macOS, Linux, or Windows.

Requires Python 3.10+ and tools/image-requirements.txt. Originals, order, and
fractional focal positions stay unchanged. --version prints the encoder/cache
identity for Gradle so changing a dependency invalidates generated assets.
"""

import argparse
import hashlib
import json
import shutil
from pathlib import Path

try:
    import PIL
    from PIL import Image, ImageOps, features
except ImportError:
    raise SystemExit(
        "Pillow is missing. Install android/tools/image-requirements.txt into "
        "a Python 3.10+ environment and select it with CHOTKI_IMAGE_PYTHON."
    )

MAX_W = 1280
MAX_H = 1920
QUALITY = 75
METHOD = 6
REQUIREMENTS = Path(__file__).with_name("image-requirements.txt")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def encoder_identity() -> str:
    if not features.check("webp"):
        raise RuntimeError("Pillow has no WebP support; install a wheel with libwebp support.")
    expected = REQUIREMENTS.read_text().strip().split("==")[1]
    if PIL.__version__ != expected:
        raise RuntimeError(f"Pillow {expected} is required; found {PIL.__version__}.")
    return (
        f"pillow-{PIL.__version__}-webp-{features.version('webp')}"
        f"-{MAX_W}x{MAX_H}-q{QUALITY}-m{METHOD}-exif-lanczos-v1"
        f"-{digest(REQUIREMENTS)}-{digest(Path(__file__))}"
    )


def convert(source: Path, destination: Path) -> None:
    # Transpose first: orientation can swap width and height or mirror pixels.
    with Image.open(source) as original:
        image = ImageOps.exif_transpose(original)
        image.thumbnail((MAX_W, MAX_H), Image.Resampling.LANCZOS)
        # Avoid propagating EXIF/ICC/XMP into the generated phone copy.
        image = image.convert("RGBA" if "A" in image.getbands() or "transparency" in image.info else "RGB")
        image.info.clear()
        temporary = destination.with_suffix(".tmp.webp")
        try:
            image.save(temporary, "WEBP", quality=QUALITY, method=METHOD)
            temporary.replace(destination)
        finally:
            temporary.unlink(missing_ok=True)


def generate(source: Path, asset_root: Path) -> None:
    identity = encoder_identity()  # Fail before changing generated assets.
    output = asset_root / "sayings"
    if source.resolve() == output.resolve() or source.resolve() in output.resolve().parents:
        raise ValueError("Generated assets must be outside the source library.")
    names = [line.strip() for line in (source / "order.txt").read_text().splitlines() if line.strip()]
    destinations = [Path(name).with_suffix(".webp").name for name in names]
    if len(set(destinations)) != len(destinations):
        raise ValueError("Image names collide after conversion to WebP.")
    for name in names:
        if not (source / Path(name).name).is_file():
            raise FileNotFoundError(f"missing picture {name}")
    metadata = source / "approved-sources.json"
    if not metadata.is_file():
        raise FileNotFoundError(metadata)

    output.mkdir(parents=True, exist_ok=True)
    manifest_path = output / "shrink-manifest.json"
    try:
        previous = json.loads(manifest_path.read_text())
    except (FileNotFoundError, ValueError):
        previous = {}
    cached = previous.get("images", {}) if previous.get("encoder") == identity else {}
    current = {}
    for name, dest_name in zip(names, destinations):
        src, dest = source / Path(name).name, output / dest_name
        source_hash = digest(src)
        entry = cached.get(dest_name, {})
        if not (entry.get("source") == source_hash and dest.is_file()
                and entry.get("output") == digest(dest)):
            convert(src, dest)
        current[dest_name] = {"source": source_hash, "output": digest(dest)}

    (output / "order.txt").write_text("".join(f"sayings/{name}\n" for name in destinations))
    shutil.copyfile(metadata, output / metadata.name)
    (output / "shrink-stamp.txt").write_text(identity)
    manifest_path.write_text(json.dumps({"encoder": identity, "images": current}, sort_keys=True))
    keep = set(destinations) | {"order.txt", metadata.name, "shrink-stamp.txt", manifest_path.name}
    for child in output.iterdir():
        if child.name not in keep:
            child.unlink()
    total = sum((output / name).stat().st_size for name in destinations)
    print(f"shrunk {len(destinations)} pictures to {total / 1_000_000:.1f} MB")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", action="store_true")
    parser.add_argument("source", type=Path, nargs="?")
    parser.add_argument("output", type=Path, nargs="?")
    args = parser.parse_args()
    try:
        if args.version:
            print(encoder_identity())
        elif args.source is not None and args.output is not None:
            generate(args.source, args.output)
        else:
            parser.error("source and output are required")
    except (RuntimeError, ValueError, OSError) as error:
        parser.exit(1, f"image packaging: {error}\n")


if __name__ == "__main__":
    main()
