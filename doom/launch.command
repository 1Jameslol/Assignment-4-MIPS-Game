#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
mars_jar="${MARS_JAR:-/Applications/Mars.jar}"
if [[ ! -f "$mars_jar" ]]; then
    echo "MARS was not found at $mars_jar"
    echo "Download MARS 4.5 from https://dpetersanderson.github.io/download.html"
    echo "Then run: MARS_JAR=/path/to/Mars.jar ./launch.command"
    exit 1
fi
echo "Open $PWD/doom.asm in MARS, then Assemble (F3)."
echo "Bitmap Display: units 4x4; display 512x512; base 0x10010000."
echo "Connect Bitmap Display and Keyboard and Display MMIO Simulator to MIPS."
echo "Run (F5), then type in the keyboard tool's lower input area."
echo "W/S move | A/D turn | Z/C strafe | SPACE shoot | M map | R restart | Q quit"
exec java -jar "$mars_jar"
