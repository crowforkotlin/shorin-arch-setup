#!/usr/bin/env bash
set -euo pipefail

for _ in $(seq 1 60); do
  if wp="$(dms ipc call wallpaper get 2>/dev/null)"; then
    case "$wp" in
      ""|\#*)
        exit 0
        ;;
      /*)
        dms ipc call wallpaper set "$wp" >/dev/null
        exit 0
        ;;
    esac
  fi

  sleep 0.5
done

exit 1
