#!/usr/bin/env python3
"""Make the Android copy of the daily pictures.

The Mac library stays as it is. This writes a WebP copy fit inside 1280 by 1920,
which covers the Home card: a phone-width strip, 220dp tall, plus the small
drift onto the focal point. Focal points are fractions of the picture, so they
still land on the same place. A file stored on its side is turned upright first,
because the phone draws the pixels as stored and the Mac does not.
"""

import shutil
import struct
import subprocess
import sys
from pathlib import Path

MAX_W = 1280
MAX_H = 1920
QUALITY = "75"
# upright: a file whose pixels are stored sideways is turned before encoding.
# The Mac shows that file upright; BitmapFactory does not.
STAMP = f"{MAX_W}x{MAX_H}-q{QUALITY}-upright"


def cwebp_bin() -> str:
    found = shutil.which("cwebp")
    if found:
        return found
    for candidate in ("/opt/homebrew/bin/cwebp", "/usr/local/bin/cwebp"):
        if Path(candidate).is_file():
            return candidate
    sys.exit("cwebp is not installed; the Android pictures cannot be shrunk")


def jpeg_orientation(path: Path) -> int:
    """EXIF orientation, or 1 when the file does not say. Reads the SHORT, not the padding."""
    data = path.read_bytes()
    if not data.startswith(b"\xff\xd8"):
        return 1
    index = 2
    while index + 4 < len(data):
        if data[index] != 0xFF:
            index += 1
            continue
        marker = data[index + 1]
        if marker in (0xD8, 0x01) or 0xD0 <= marker <= 0xD7:
            index += 2
            continue
        if marker in (0xD9, 0xDA):
            break
        segment_len = struct.unpack(">H", data[index + 2 : index + 4])[0]
        if marker == 0xE1 and data[index + 4 : index + 10] == b"Exif\x00\x00":
            return tiff_orientation(data[index + 10 : index + 2 + segment_len])
        index += 2 + segment_len
    return 1


def tiff_orientation(tiff: bytes) -> int:
    if len(tiff) < 8 or tiff[:2] not in (b"II", b"MM"):
        return 1
    order = "<" if tiff[:2] == b"II" else ">"
    if struct.unpack(order + "H", tiff[2:4])[0] != 42:
        return 1
    offset = struct.unpack(order + "I", tiff[4:8])[0]
    if offset + 2 > len(tiff):
        return 1
    count = struct.unpack(order + "H", tiff[offset : offset + 2])[0]
    entry = offset + 2
    for _ in range(count):
        if entry + 12 > len(tiff):
            return 1
        tag, typ, n = struct.unpack(order + "HHI", tiff[entry : entry + 8])
        if tag == 0x0112 and typ == 3 and n >= 1:
            return struct.unpack(order + "H", tiff[entry + 8 : entry + 10])[0]
        entry += 12
    return 1


def dimensions(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return struct.unpack(">II", data[16:24])
    index = 2
    while index < len(data) - 8:
        if data[index] != 0xFF:
            index += 1
            continue
        marker = data[index + 1]
        if marker in (0xC0, 0xC1, 0xC2):
            height, width = struct.unpack(">HH", data[index + 5 : index + 9])
            return width, height
        if marker in (0xD8, 0xD9) or 0xD0 <= marker <= 0xD7:
            index += 2
            continue
        segment = struct.unpack(">H", data[index + 2 : index + 4])[0]
        index += 2 + segment
    sys.exit(f"could not read the size of {path.name}")


# How far to turn the stored pixels so they match the picture the Mac shows.
# 6 is a quarter-turn clockwise, 8 is a quarter-turn the other way, 3 is a half-turn.
TURNS = {3: "180", 6: "90", 8: "270"}


def upright_copy(src: Path, temp: Path) -> Path:
    orientation = jpeg_orientation(src)
    if orientation in (0, 1):
        return src
    degrees = TURNS.get(orientation)
    if degrees is None:
        sys.exit(f"{src.name} is mirrored in a way this packager does not turn ({orientation})")
    subprocess.check_call(
        ["/usr/bin/sips", "-r", degrees, str(src), "--out", str(temp)],
        stdout=subprocess.DEVNULL,
    )
    return temp


def main() -> None:
    source = Path(sys.argv[1])
    output = Path(sys.argv[2]) / "sayings"
    output.mkdir(parents=True, exist_ok=True)
    encoder = cwebp_bin()
    stamp_path = output / "shrink-stamp.txt"
    fresh = stamp_path.read_text() == STAMP if stamp_path.is_file() else False

    names = [
        line.strip()
        for line in (source / "order.txt").read_text().splitlines()
        if line.strip()
    ]
    written: list[str] = []
    for name in names:
        src = source / Path(name).name
        if not src.is_file():
            sys.exit(f"missing picture {name}")
        dest_name = Path(name).with_suffix(".webp").name
        dest = output / dest_name
        if not (fresh and dest.is_file() and dest.stat().st_mtime >= src.stat().st_mtime):
            encode_from = upright_copy(src, output / f".orient-{dest_name}.jpg")
            try:
                width, height = dimensions(encode_from)
                scale = min(MAX_W / width, MAX_H / height, 1)
                command = [
                    encoder, "-quiet", "-q", QUALITY, "-m", "6", "-metadata", "none",
                ]
                if scale < 0.999:
                    command += [
                        "-resize",
                        str(max(1, round(width * scale))),
                        str(max(1, round(height * scale))),
                    ]
                command += [str(encode_from), "-o", str(dest)]
                subprocess.check_call(command)
            finally:
                if encode_from != src:
                    encode_from.unlink(missing_ok=True)
        written.append(f"sayings/{dest_name}")

    (output / "order.txt").write_text("\n".join(written) + "\n")
    shutil.copyfile(source / "approved-sources.json", output / "approved-sources.json")
    stamp_path.write_text(STAMP)

    keep = {Path(line).name for line in written}
    keep.update({"order.txt", "approved-sources.json", "shrink-stamp.txt"})
    for child in output.iterdir():
        if child.name not in keep:
            child.unlink()

    total = sum((output / Path(line).name).stat().st_size for line in written)
    print(f"shrunk {len(written)} pictures to {total / 1_000_000:.1f} MB")


if __name__ == "__main__":
    main()
