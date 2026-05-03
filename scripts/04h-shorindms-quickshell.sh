#!/bin/bash

# ==============================================================================
# 04-dms-setup.sh - DMS Desktop (Pre-install separated + Pre-Verify)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

if [[ -f "$SCRIPT_DIR/00-utils.sh" ]]; then
    source "$SCRIPT_DIR/00-utils.sh"
else
    echo "Error: 00-utils.sh not found in $SCRIPT_DIR."
    exit 1
fi

check_root
VERIFY_LIST="/tmp/shorin_install_verify.list"
rm -f "$VERIFY_LIST"

# --- Identify User & DM Check ---
log "Identifying target user..."
detect_target_user


if [[ -z "$TARGET_USER" || ! -d "$HOME_DIR" ]]; then
    error "Target user invalid or home directory does not exist."
    exit 1
fi

info_kv "Target User" "$TARGET_USER"
check_dm_conflict
log "DM Check result $SKIP_DM"
# --- Temporary Sudo Privileges ---
log "Granting temporary sudo privileges..."
SUDO_TEMP_FILE="/etc/sudoers.d/99_shorin_installer_temp"
echo "$TARGET_USER ALL=(ALL) NOPASSWD: ALL" > "$SUDO_TEMP_FILE"
chmod 440 "$SUDO_TEMP_FILE"

cleanup_sudo() {
    if [[ -f "$SUDO_TEMP_FILE" ]]; then
        rm -f "$SUDO_TEMP_FILE"
        log "Security: Temporary sudo privileges revoked."
    fi
}
trap cleanup_sudo EXIT INT TERM

critical_failure_handler() {
    local failed_reason="$1"
    trap - ERR
    echo -e "\n\033[0;31m[CRITICAL FAILURE] $failed_reason\033[0m\n"
    # 这里省略了你原有的报错大框框，保持原有逻辑即可
    exit 1
}
trap 'critical_failure_handler "Script Error at Line $LINENO"' ERR

AUR_HELPER="paru"

apply_shorindms_overrides() {
    local overrides_dir="$PARENT_DIR/shorindms-overrides"

    if [[ ! -d "$overrides_dir" ]]; then
        warn "Fork override directory not found: $overrides_dir"
        return 0
    fi

    log "Applying fork-managed Shorin DMS overrides..."
    force_copy "$overrides_dir/." "$HOME_DIR/"
    chown -R "$TARGET_USER:$TARGET_USER" \
        "$HOME_DIR/.config/ghostty" \
        "$HOME_DIR/.config/scripts" \
        "$HOME_DIR/.config/matugen" 2>/dev/null || true
}

patch_dms_keybinds() {
    local binds_file="$HOME_DIR/.config/niri/dms/binds.kdl"

    if [[ ! -f "$binds_file" ]]; then
        warn "DMS binds file not found: $binds_file"
        return 0
    fi

    log "Patching DMS keybinds for Chrome and Ghostty..."
    sed -i -E \
        -e 's|^[[:space:]]*Mod\+B[[:space:]].*$|    Mod+B hotkey-overlay-title="浏览器 Browser" { spawn "flatpak" "run" "com.google.Chrome"; }|' \
        -e 's|^[[:space:]]*Mod\+T[[:space:]].*$|    Mod+T hotkey-overlay-title="共享终端 Terminal" { spawn "ghostty" "--gtk-single-instance=true"; }|' \
        "$binds_file"
    chown "$TARGET_USER:$TARGET_USER" "$binds_file"
}

prioritize_ghostty_terminal() {
    local terminals_file="$HOME_DIR/.config/xdg-terminals.list"
    local tmp_file

    log "Prioritizing Ghostty in xdg-terminals.list..."
    mkdir -p "$HOME_DIR/.config"
    tmp_file=$(mktemp)
    {
        printf '%s\n' 'ghostty.desktop' 'kitty.desktop'
        if [[ -f "$terminals_file" ]]; then
            grep -vxF 'ghostty.desktop' "$terminals_file" | grep -vxF 'kitty.desktop' || true
        fi
    } > "$tmp_file"
    install -o "$TARGET_USER" -g "$TARGET_USER" -m 644 "$tmp_file" "$terminals_file"
    rm -f "$tmp_file"
}

configure_nautilus_terminal() {
    if as_user gsettings list-schemas | grep -q '^com.github.stunkymonkey.nautilus-open-any-terminal$'; then
        log "Configuring Nautilus terminal integration to Ghostty..."
        sudo -u "$TARGET_USER" dbus-run-session \
            gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal ghostty
    fi
}

configure_chrome_browser_defaults() {
    local desktop_id="com.google.Chrome.desktop"
    local system_desktop="/var/lib/flatpak/exports/share/applications/$desktop_id"
    local user_desktop="$HOME_DIR/.local/share/flatpak/exports/share/applications/$desktop_id"

    if [[ ! -f "$system_desktop" && ! -f "$user_desktop" ]]; then
        warn "Chrome desktop entry not found, skipping browser default configuration."
        return 0
    fi

    log "Setting Chrome as default browser..."
    as_user xdg-settings set default-web-browser "$desktop_id" || warn "Failed to set xdg-settings browser default."
    as_user xdg-mime default "$desktop_id" x-scheme-handler/http x-scheme-handler/https text/html || warn "Failed to set xdg-mime browser defaults."
}

# ==============================================================================
# STEP 1: Pre-requisites Installation
# ==============================================================================
section "Shorin DMS" "Installing Pre-requisites"

PRE_PKGS="quickshell-git vulkan-headers xdg-desktop-portal-gnome"

log "Generating verify list for pre-requisites..."
echo "$PRE_PKGS" | tr ' ' '\n' >> "$VERIFY_LIST"

log "Installing pre-requisites explicitly..."
if ! as_user "$AUR_HELPER" -S --noconfirm --needed $PRE_PKGS; then
    critical_failure_handler "Failed to install pre-requisites: $PRE_PKGS"
fi

# ==============================================================================
# STEP 2: Core Meta Environment
# ==============================================================================
section "Shorin DMS" "Installing Core Environment"
CORE_PKG="shorin-dms-niri-git"

log "Fetching dependency list from AUR for verification..."
echo "$CORE_PKG" >> "$VERIFY_LIST"
# 使用 -Si 查询远程信息，提前写入清单 (剥离版本号 <>=)
if as_user "$AUR_HELPER" -Si "$CORE_PKG" &>/dev/null; then
    as_user "$AUR_HELPER" -Si "$CORE_PKG" | grep "^Depends On" | cut -d':' -f2- | tr -s ' ' '\n' | sed -e 's/[<>=].*//g' -e '/^$/d' -e '/None/d' >> "$VERIFY_LIST"
    log "Dependencies added to $VERIFY_LIST."
else
    warn "Could not fetch remote dependency info for $CORE_PKG. Skipping verify list append."
fi

log "Installing $CORE_PKG environment via AUR..."
if ! as_user "$AUR_HELPER" -S --noconfirm --needed "$CORE_PKG"; then
    critical_failure_handler "Failed to install $CORE_PKG"
fi

# ==============================================================================
# STEP 3: Initialize Dotfiles & Environment
# ==============================================================================
log "Initializing User Dotfiles and Environment..."
exe as_user shorindms init

section "Shorin DMS" "Installing Fork Extras"

EXTRA_PKGS="ghostty nautilus-open-any-terminal xdg-terminal-exec"
log "Installing fork extra packages..."
echo "$EXTRA_PKGS" | tr ' ' '\n' >> "$VERIFY_LIST"
if ! as_user "$AUR_HELPER" -S --noconfirm --needed $EXTRA_PKGS; then
    critical_failure_handler "Failed to install fork extra packages: $EXTRA_PKGS"
fi

if flatpak info com.google.Chrome &>/dev/null; then
    log "Google Chrome already installed, skipping."
else
    log "Installing Google Chrome from Flathub..."
    if ! exe flatpak install -y flathub com.google.Chrome; then
        critical_failure_handler "Failed to install Google Chrome from Flathub"
    fi
fi

apply_shorindms_overrides
if [[ -f "$HOME_DIR/.config/scripts/matugen-update.sh" ]]; then
    chmod +x "$HOME_DIR/.config/scripts/matugen-update.sh"
    chown "$TARGET_USER:$TARGET_USER" "$HOME_DIR/.config/scripts/matugen-update.sh"
fi
patch_dms_keybinds
prioritize_ghostty_terminal
configure_nautilus_terminal
configure_chrome_browser_defaults

# ==============================================================================
# STEP 4: Static Resources
# ==============================================================================
section "Shorin DMS" "Wallpapers & Tutorials"

log "Deploying wallpapers..."
WALLPAPER_SOURCE_DIR="$PARENT_DIR/resources/Wallpapers"
WALLPAPER_DIR="$HOME_DIR/Pictures/Wallpapers"
if [ -d "$WALLPAPER_SOURCE_DIR" ]; then
    as_user mkdir -p "$WALLPAPER_DIR"
    force_copy "$WALLPAPER_SOURCE_DIR/." "$WALLPAPER_DIR/"
    chown -R "$TARGET_USER:" "$WALLPAPER_DIR"
fi

# ==============================================================================
# Finalization & Auto-Login
# ==============================================================================
section "Final" "Auto-Login & Cleanup"


log "Cleaning up legacy TTY autologin configs..."

if [[ "$SKIP_DM" == false ]]; then
    setup_ly
fi

success "Shorin DMS Niri Installation Complete!"
