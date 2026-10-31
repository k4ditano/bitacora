#!/bin/sh
# Bitácora: builds it and puts it where the desktop finds it (~/.local), for this user.
#   sh install.sh
set -eu
cd "$(dirname "$0")"
cargo build --release
mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications" "$HOME/.local/share/icons/hicolor/scalable/apps"
# (Written beside and then moved: the windows open keep running the one they started with.)
cp target/release/bitacora "$HOME/.local/bin/.bitacora.new"
mv -f "$HOME/.local/bin/.bitacora.new" "$HOME/.local/bin/bitacora"
cp data/bitacora.desktop "$HOME/.local/share/applications/bitacora.desktop"
cp data/bitacora.svg "$HOME/.local/share/icons/hicolor/scalable/apps/bitacora.svg"
echo "bitacora: installed in ~/.local/bin (and in the applications)"
