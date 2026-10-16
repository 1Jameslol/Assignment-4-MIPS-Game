#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
mars_jar="${MARS_JAR:-/Applications/Mars.jar}"
if [[ ! -f "$mars_jar" ]]; then
    echo "Set MARS_JAR to your MARS 4.5 jar file."
    exit 1
fi
exec java --class-path "$mars_jar" common/Arcade.java "$@"
