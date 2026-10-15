#!/usr/bin/env python3
"""Add two original gradient images to a booted test simulator's Photos library.

Usage: python3 scripts/seed_test_photos.py SIMULATOR_UUID
Run once before the PhotoKit UI suite. No user files or network assets are read.
"""
import pathlib
import struct
import subprocess
import sys
import tempfile
import zlib


def chunk(kind, data):
    return struct.pack("!I", len(data)) + kind + data + struct.pack("!I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def gradient(color):
    width = height = 256
    raw = b"".join(b"\0" + b"".join(bytes(min(255, int(c + (x + y) * 0.14)) for c in color)
                                  for x in range(width)) for y in range(height))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack("!2I5B", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    with tempfile.TemporaryDirectory(prefix="homepad-photos-") as directory:
        paths = []
        for name, color in [("teal", (12, 85, 90)), ("sand", (158, 120, 86))]:
            path = pathlib.Path(directory) / f"{name}.png"
            path.write_bytes(gradient(color)); paths.append(str(path))
        subprocess.run(["xcrun", "simctl", "addmedia", sys.argv[1], *paths], check=True)
