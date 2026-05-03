#!/usr/bin/env bash
set -euo pipefail

export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-niri}"
export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-wayland}"

dbus-update-activation-environment --systemd \
    DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE \
    XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS

systemctl --user import-environment \
    DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE \
    XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS

systemctl --user restart \
    xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk
