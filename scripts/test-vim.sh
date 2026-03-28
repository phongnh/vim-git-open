#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
exec vim -Nu NONE -n -es -S tests/vim/spec.vim
