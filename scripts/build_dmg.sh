#!/usr/bin/env bash
# Build DMG macOS untuk versi tertentu.
# Pemakaian: scripts/build_dmg.sh 1.1.0
# Opsional:  GODOT=/path/ke/Godot scripts/build_dmg.sh 1.1.0
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)}"
GODOT="${GODOT:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"

# Tulis versi ke project.godot supaya tampil di menu game.
sed -i '' "s/^config\/version=.*/config\/version=\"$VERSION\"/" project.godot

mkdir -p build
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "macOS" "build/DesaBahagia-$VERSION.dmg"
echo "Selesai: build/DesaBahagia-$VERSION.dmg"
