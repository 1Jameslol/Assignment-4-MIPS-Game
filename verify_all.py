#!/usr/bin/env python3
"""Regression suites + actual framebuffer previews + GUI adapter integration."""
from pathlib import Path
import os
import runpy
import struct
import subprocess
import tempfile
import zlib

ROOT = Path(__file__).resolve().parent
MARS = os.environ.get("MARS_JAR", "/Applications/Mars.jar")
chunk = runpy.run_path(str(ROOT / "doom/verify.py"))["png_chunk"]


def run(command):
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=120)
    print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="")
    if result.returncode:
        raise SystemExit(result.returncode)
    return result.stdout


def verify(game, source, colors):
    with tempfile.TemporaryDirectory(prefix="mips-arcade-") as temp:
        dump = Path(temp) / "frame.bin"
        output = run(["java", "-Djava.awt.headless=true", "-jar", MARS,
                      "nc", "ae1", "se1", "sm", "20000000", "dump",
                      "0x10010000-0x10020000", "Binary", str(dump),
                      str(ROOT / game / source), "pa", "--test"])
        if "SELFTEST PASS" not in output:
            raise AssertionError(f"{game}: missing test completion")
        data = dump.read_bytes()
    assert len(data) == 65536, f"{game}: incomplete framebuffer"
    pixels = struct.unpack("<16384I", data)
    assert all(c <= 0xFFFFFF for c in pixels), f"{game}: invalid pixel"
    for color in colors:
        assert color in pixels, f"{game}: missing GUI color {color:x}"
    if game == "blackjack":
        assert pixels[35 * 128 + 27] == 0x416D99, "Dealer hole card must be hidden"
    scanlines = bytearray()
    for y in range(128):
        row = bytearray([0])
        for c in pixels[y * 128:(y + 1) * 128]:
            row.extend(bytes((c >> 16, (c >> 8) & 255, c & 255)) * 4)
        scanlines.extend(row * 4)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", 512, 512, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(scanlines, 9)) + chunk(b"IEND", b"")
    (ROOT / game / "preview.png").write_bytes(png)
    print(f"{game}: framebuffer checks passed")


def main():
    import sys
    run([sys.executable, str(ROOT / "doom/verify.py")])
    verify("tic-tac-toe", "tic_tac_toe.asm", [0x6DE3C3, 0xFFBC72, 0x628399])
    verify("blackjack", "blackjack.asm", [0xF5EBD6, 0x416D99, 0xFFD68A])
    for game in ["doom", "tic-tac-toe", "blackjack"]:
        output = run(["java", "-Djava.awt.headless=true", "--class-path", MARS,
                      "common/Arcade.java", "--smoke", game])
        if "GUI SMOKE PASS" not in output:
            raise AssertionError(f"{game}: GUI adapter test did not finish")
    print("ALL THREE GAMES PASSED")


if __name__ == "__main__":
    main()
