#!/usr/bin/env python3
"""Run the MIPS game's own regression suite and export its actual framebuffer.

No third-party Python dependencies. Override the simulator with MARS_JAR.
"""
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import zlib

ROOT = Path(__file__).resolve().parent


def png_chunk(kind, data):
    return (struct.pack(">I", len(data)) + kind + data
            + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))


def main():
    mars = Path(os.environ.get("MARS_JAR", "/Applications/Mars.jar"))
    if not mars.is_file():
        raise SystemExit("Set MARS_JAR to the path of MARS 4.5's jar file.")
    with tempfile.TemporaryDirectory(prefix="mips-doom-") as temp:
        dump = Path(temp) / "frame.bin"
        result = subprocess.run([
            "java", "-Djava.awt.headless=true", "-jar", str(mars),
            "nc", "ae1", "se1", "20000000", "dump",
            "0x10010000-0x10020000", "Binary", str(dump),
            str(ROOT / "doom.asm"), "pa", "--test",
        ], capture_output=True, text=True, timeout=120)
        print(result.stdout, end="")
        if result.stderr:
            print(result.stderr, end="")
        if result.returncode or "SELFTEST PASS" not in result.stdout:
            raise SystemExit(result.returncode or 1)
        data = dump.read_bytes()
    if len(data) != 128 * 128 * 4:
        raise SystemExit(f"Wrong framebuffer size: {len(data)}")
    pixels = list(struct.unpack("<16384I", data))
    # Check meaningful visual output, not just a nonzero buffer.
    assert all(pixel <= 0xFFFFFF for pixel in pixels), "Invalid RGB values"
    assert 0xB93636 in pixels, "Initial demon is not visible"
    assert 0x66E4BC in pixels, "Player minimap marker is missing"
    assert 0xE8C9AA in pixels, "HUD text is missing"
    assert len(set(pixels)) > 25, "Scene lacks expected detail"
    # PNG at the same 4x pixel scale as the MARS display.
    scanlines = bytearray()
    for y in range(128):
        row = bytearray([0])  # PNG filter: none
        for color in pixels[y * 128:(y + 1) * 128]:
            row.extend(bytes((color >> 16, (color >> 8) & 255, color & 255)) * 4)
        scanlines.extend(row * 4)
    png = b"\x89PNG\r\n\x1a\n"
    png += png_chunk(b"IHDR", struct.pack(">IIBBBBB", 512, 512, 8, 2, 0, 0, 0))
    png += png_chunk(b"IDAT", zlib.compress(bytes(scanlines), 9))
    png += png_chunk(b"IEND", b"")
    output = ROOT / "preview.png"
    output.write_bytes(png)
    print(f"Framebuffer checks passed. Preview: {output}")


if __name__ == "__main__":
    main()
