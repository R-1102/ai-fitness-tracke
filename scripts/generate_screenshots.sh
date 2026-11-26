#!/usr/bin/env bash
# Generates the README screenshots (docs/screenshots/*.png) and GIFs
# (docs/gifs/*.gif) automatically from the real app screens with sample data.
# No phone, no camera, no Firebase needed.
#
# Usage (from the project root):   bash scripts/generate_screenshots.sh
# Requires ffmpeg for the GIFs:    brew install ffmpeg
set -euo pipefail

FRAMES=build/screenshot_frames
rm -rf "$FRAMES"
mkdir -p docs/screenshots docs/gifs

echo "→ Rendering screens…"
flutter test test/screenshots_test.dart --dart-define=SCREENSHOTS=true

if ! command -v ffmpeg >/dev/null; then
  echo "! ffmpeg not found — screenshots are done; install ffmpeg (brew install ffmpeg) and re-run for GIFs."
  exit 0
fi

make_gif() { # <frames dir> <output gif> <width>
  local dir="$1" out="$2" width="$3"
  local palette="${TMPDIR:-/tmp}/palette_$$.png"
  local filters="fps=15,scale=${width}:-1:flags=lanczos"
  ffmpeg -v warning -framerate 15 -i "$dir/%04d.png" -vf "${filters},palettegen=stats_mode=diff" -frames:v 1 -update 1 -y "$palette"
  ffmpeg -v warning -framerate 15 -i "$dir/%04d.png" -i "$palette" \
    -lavfi "${filters} [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" -loop 0 -y "$out"
  rm -f "$palette"
  echo "✓ $out ($(( $(wc -c < "$out") / 1024 )) KB)"
}

echo "→ Building GIFs…"
make_gif "$FRAMES/welcome" docs/gifs/welcome.gif 320
make_gif "$FRAMES/app-tour" docs/gifs/app-tour.gif 320

echo
echo "✓ Done:"
ls -1 docs/screenshots docs/gifs
