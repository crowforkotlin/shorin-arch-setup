#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $(basename "$0") <wallpaper-path>" >&2
    exit 1
fi

wallpaper_path="$1"

if [[ ! -f "$wallpaper_path" ]]; then
    echo "Wallpaper not found: $wallpaper_path" >&2
    exit 1
fi

exec matugen image "$wallpaper_path" -q --source-color-index 0
