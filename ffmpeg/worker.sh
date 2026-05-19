#!/bin/sh
set -eu

if [ -z "${SOURCE_URL:-}" ] || [ -z "${TARGET_URL:-}" ]; then
  echo "SOURCE_URL and TARGET_URL must be provided. Worker is idle."
  tail -f /dev/null
fi

exec ffmpeg -hide_banner -loglevel info -re -i "$SOURCE_URL" \
  -c:v "${VIDEO_CODEC:-copy}" \
  -c:a "${AUDIO_CODEC:-aac}" \
  -f flv "$TARGET_URL"