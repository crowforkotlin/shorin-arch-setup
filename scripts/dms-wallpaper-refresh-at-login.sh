#!/usr/bin/env bash
set -euo pipefail

for _ in $(seq 1 60); do
  if dms ipc call settings get blurredWallpaperLayer >/dev/null 2>&1; then
    layer_enabled="$(dms ipc call settings get blurredWallpaperLayer 2>/dev/null || printf 'false')"

    if [ "$layer_enabled" = "true" ]; then
      dms ipc call settings set blurredWallpaperLayer false >/dev/null
      sleep 0.3
    fi

    if wp="$(dms ipc call wallpaper get 2>/dev/null)"; then
      case "$wp" in
        ""|\#*)
          ;;
        /*)
          wp_real="$(realpath -m -- "$wp")"
          wp_refresh="$(dirname "$wp_real")/./$(basename "$wp_real")"
          dms ipc call wallpaper set "$wp_refresh" >/dev/null
          sleep 0.3
          dms ipc call wallpaper set "$wp_real" >/dev/null
          ;;
      esac
    fi

    if [ "$layer_enabled" = "true" ]; then
      sleep 0.3
      dms ipc call settings set blurredWallpaperLayer true >/dev/null
    fi

    exit 0
  fi

  sleep 0.5
done

exit 1
