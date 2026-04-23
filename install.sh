#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="/usr/local/bin"

if [[ -L "$INSTALL_DIR/ulh" || -f "$INSTALL_DIR/ulh" ]]; then
  echo "Removing existing ulh at $INSTALL_DIR/ulh"
  rm "$INSTALL_DIR/ulh"
fi

ln -s "$SCRIPT_DIR/ulh" "$INSTALL_DIR/ulh"
echo "✓ Installed: ulh → $SCRIPT_DIR/ulh"
echo "  Run 'ulh help' to get started."
