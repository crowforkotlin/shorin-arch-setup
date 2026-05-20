#!/usr/bin/env bash
set -euo pipefail

has_niri_layer() {
  local namespace="$1"

  niri msg -j layers 2>/dev/null | grep -Fq "\"namespace\":\"$namespace\""
}

for _ in $(seq 1 120); do
  if ! dms ipc call settings get blurredWallpaperLayer >/dev/null 2>&1; then
    sleep 0.5
    continue
  fi

  layer_enabled="$(dms ipc call settings get blurredWallpaperLayer 2>/dev/null || printf 'false')"

  if ! wp="$(dms ipc call wallpaper get 2>/dev/null)"; then
    sleep 0.5
    continue
  fi

  case "$wp" in
    ""|\#*)
      sleep 0.5
      continue
      ;;
    /*)
      ;;
    *)
      sleep 0.5
      continue
      ;;
  esac

  if ! has_niri_layer "quickshell"; then
    sleep 0.5
    continue
  fi

  if [ "$layer_enabled" = "true" ] && ! has_niri_layer "dms:blurwallpaper"; then
    sleep 0.5
    continue
  fi

  if [ "$layer_enabled" = "true" ]; then
    dms ipc call settings set blurredWallpaperLayer false >/dev/null
    sleep 0.3
  fi

  wp_real="$(realpath -m -- "$wp")"
  wp_refresh="$(dirname "$wp_real")/./$(basename "$wp_real")"
  dms ipc call wallpaper set "$wp_refresh" >/dev/null
  sleep 0.3
  dms ipc call wallpaper set "$wp_real" >/dev/null

  if [ "$layer_enabled" = "true" ]; then
    sleep 0.3
    dms ipc call settings set blurredWallpaperLayer true >/dev/null
  fi

  exit 0
done

exit 1
