#!/bin/bash
set -euo pipefail

game="${1:-}"
if [[ -z "$game" ]]; then
    echo "Usage: $0 {blackjack|tic-tac-toe|doom}"
    exit 2
fi

mars_jar="${MARS_JAR:-/Applications/Mars.jar}"
if [[ ! -f "$mars_jar" ]]; then
    echo "MARS was not found at $mars_jar"
    echo "Download MARS 4.5 from https://dpetersanderson.github.io/download.html"
    echo "Then run: MARS_JAR=/path/to/Mars.jar $0 $game"
    exit 1
fi

case "$game" in
    blackjack|tic-tac-toe|doom) ;;
    *) echo "Unknown game: $game"; exit 2 ;;
esac

cd -- "$game"
asm_file="${game//-/_}.asm"
echo "Open $PWD/$asm_file in MARS, then Assemble (F3)."
echo "Bitmap Display: units 4x4; display 512x512; base 0x10010000."
echo "Connect Bitmap Display and Keyboard and Display MMIO Simulator to MIPS."
exec java -jar "$mars_jar"

