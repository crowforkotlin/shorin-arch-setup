#!/usr/bin/env bash

exec env GSK_RENDERER=gl GTK_IM_MODULE=fcitx nautilus --new-window "$@"
