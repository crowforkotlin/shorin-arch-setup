#!/usr/bin/env bash
set -euo pipefail

for _ in $(seq 1 60); do
  if dms ipc call lock lock >/dev/null 2>&1; then
    exit 0
  fi
  sleep 0.5
done

exit 1
EOF
