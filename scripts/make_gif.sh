#!/usr/bin/env bash
# Turns a screen recording (.mov / .mp4) into a small, good-looking GIF for the README.
#
# Usage:
#   bash scripts/make_gif.sh <input video> <output.gif> [start sec] [duration sec] [width px] [fps]
#
# Examples:
#   bash scripts/make_gif.sh ~/Desktop/squats.MOV docs/gifs/live-workout.gif 3 8
#   bash scripts/make_gif.sh ~/Desktop/tour.MOV   docs/gifs/app-tour.gif     0 12 300 12
#
# Requires ffmpeg:  brew install ffmpeg
set -euo pipefail

if [ $# -lt 2 ]; then
  sed -n '2,10p' "$0"
  exit 1
fi

IN="$1"
OUT="$2"
START="${3:-0}"
DURATION="${4:-8}"
WIDTH="${5:-320}"
FPS="${6:-15}"

command -v ffmpeg >/dev/null || { echo "ffmpeg not found — install it with: brew install ffmpeg"; exit 1; }
mkdir -p "$(dirname "$OUT")"

PALETTE="${TMPDIR:-/tmp}/palette_$$.png"
FILTERS="fps=${FPS},scale=${WIDTH}:-1:flags=lanczos"

# Pass 1: build an optimal 256-colour palette for this clip.
ffmpeg -v warning -ss "$START" -t "$DURATION" -i "$IN" -vf "${FILTERS},palettegen=stats_mode=diff" -frames:v 1 -update 1 -y "$PALETTE"
# Pass 2: encode the GIF with that palette (much sharper than a plain conversion).
ffmpeg -v warning -ss "$START" -t "$DURATION" -i "$IN" -i "$PALETTE" \
  -lavfi "${FILTERS} [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" -y "$OUT"
rm -f "$PALETTE"

SIZE_KB=$(( $(wc -c < "$OUT") / 1024 ))
echo "✓ Created $OUT (${SIZE_KB} KB)"
if [ "$SIZE_KB" -gt 8000 ]; then
  echo "  Tip: over 8 MB loads slowly on GitHub — try a shorter duration, width 280 or fps 12."
fi
