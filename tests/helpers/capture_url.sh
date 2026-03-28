#!/bin/sh
set -eu
: "${GIT_OPEN_CAPTURE_FILE:?GIT_OPEN_CAPTURE_FILE is required}"
printf '%s\n' "$1" > "$GIT_OPEN_CAPTURE_FILE"
