#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
exec nvim --headless -u NONE -c "set rtp^=$(pwd)" -c "luafile tests/lua/spec.lua"
