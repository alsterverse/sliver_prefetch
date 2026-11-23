#!/bin/sh
# Renders the README demo and encodes it to doc/demo.webp. Needs ffmpeg with
# libwebp. Run from anywhere.
set -eu
cd "$(dirname "$0")/.."
frames=build/demo_frames
DEMO_FRAMES=$frames flutter test tool/record_demo_test.dart
mkdir -p ../doc
ffmpeg -v error -y -framerate 30 -i "$frames/%04d.png" \
  -vf 'scale=812:-1:flags=lanczos' \
  -c:v libwebp_anim -lossless 0 -q:v 75 -compression_level 6 -loop 0 \
  ../doc/demo.webp
ls -l ../doc/demo.webp
