#!/bin/sh
# Shim installed as the Homebrew cask's `binary` target. Resolves symlinks
# back to the real path inside peek.app so that Bundle.main points at the
# .app (not /opt/homebrew/bin) and SwiftPM can locate peek_peek.bundle.
set -e
SELF="$0"
while [ -L "$SELF" ]; do
  LINK="$(readlink "$SELF")"
  case "$LINK" in
    /*) SELF="$LINK" ;;
    *)  SELF="$(dirname "$SELF")/$LINK" ;;
  esac
done
DIR="$(cd "$(dirname "$SELF")" && pwd -P)"
exec "$DIR/peek" "$@"
