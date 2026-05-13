#!/usr/bin/env bash

if command -v thunar >/dev/null 2>&1; then
    exec thunar "$@"
fi

exec "$HOME/.config/niri/scripts/open-nautilus-gl.sh" "$@"
