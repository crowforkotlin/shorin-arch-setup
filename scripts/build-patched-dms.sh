#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 3 ]]; then
    echo "Usage: $0 <version> [debounce_ms] [output_path]" >&2
    exit 1
fi

VERSION="$1"
DEBOUNCE_MS="${2:-50}"
OUTPUT_PATH="${3:-/usr/local/bin/dms}"

if ! [[ "$DEBOUNCE_MS" =~ ^[0-9]+$ ]]; then
    echo "debounce_ms must be an integer" >&2
    exit 1
fi

for cmd in curl tar go install sed mktemp; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Missing required command: $cmd" >&2
        exit 1
    fi
done

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

ARCHIVE="DankMaterialShell-${VERSION}"
TARBALL_URL="https://github.com/AvengeMedia/DankMaterialShell/archive/refs/tags/v${VERSION}.tar.gz"
TARBALL_PATH="$WORKDIR/dms.tar.gz"

curl -fsSL "$TARBALL_URL" -o "$TARBALL_PATH"
tar -xzf "$TARBALL_PATH" -C "$WORKDIR"

SOURCE_FILE="$WORKDIR/$ARCHIVE/core/internal/server/brightness/ddc.go"

if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "Unable to find DDC backend source in downloaded archive" >&2
    exit 1
fi

sed -i "s/200\\*time.Millisecond/${DEBOUNCE_MS}*time.Millisecond/" "$SOURCE_FILE"

if ! grep -q "${DEBOUNCE_MS}\\*time.Millisecond" "$SOURCE_FILE"; then
    echo "Failed to patch DDC debounce interval" >&2
    exit 1
fi

pushd "$WORKDIR/$ARCHIVE/core" >/dev/null
go build \
    -tags distro_binary \
    -trimpath \
    -buildmode=pie \
    -mod=readonly \
    -modcacherw \
    -ldflags="-s -w -X main.Version=v${VERSION}" \
    -o dms ./cmd/dms
popd >/dev/null

install -Dm0755 "$WORKDIR/$ARCHIVE/core/dms" "$OUTPUT_PATH"
