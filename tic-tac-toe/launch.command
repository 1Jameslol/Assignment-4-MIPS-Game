#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
exec bash ./launch.command tic-tac-toe
